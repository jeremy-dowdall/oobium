import 'dart:async';
import 'dart:io';

import 'package:objectid/objectid.dart';
import 'package:oobium_common/oobium_common.dart';
import 'package:oobium_common/src/json.dart';
import 'package:oobium_common/src/string.extensions.dart';

class Database {

  final String path;
  Database(this.path);

  final _builders = <String, Function(Map data)>{};
  final _models = <String, DataModel>{};
  int _dataFileSize;
  IOSink _dataSink;
  Completer<void> _compactCompleter;
  List<DataRecord> _dataBuffer;
  Completer<Stream<List<int>>> _replicateCompleter;

  void addBuilder<T>(T builder(Map data)) {
    _builders[T.toString()] = builder;
  }

  Future<void> open() async {
    if(_dataSink != null) {
      return;
    }
    await Directory(path).parent.create(recursive: true);
    await _openInit();
    await _openData();
    await _openSync();
  }

  Future<void> _openInit() async {
    final file = File('$path.init');
    if(await file.exists()) {
      final lines = await file.readAsLines();
      if(lines.isNotEmpty) {
        IOSink sink;
        String section;
        for(var line in lines) {
          print('init $line');
          if(line.startsWith('[') && line.endsWith(']')) {
            await sink?.flush();
            await sink?.close();
            sink = null;
            section = line.substring(1, line.length - 1).trim();
          }
          else if(section == 'sync') {
            sink ??= File('$path.sync').openWrite(mode: FileMode.writeOnly);
            sink.writeln(SyncRecord.fromLine(line));
          }
          else if(section == 'data') {
            sink ??= File(path).openWrite(mode: FileMode.writeOnly);
            sink.writeln(DataRecord.fromLine(line));
          }
          else {
            throw Exception('unknown section: $section');
          }
        }
        await sink?.flush();
        await sink?.close();
      }
      await file.delete();
    }
  }
  
  Future<void> _openData() async {
    final file = File(path);
    if(await file.exists()) {
      final lines = await file.readAsLines();
      _dataFileSize = lines.length;
      for(var line in lines) {
        final record = DataRecord.fromLine(line);
        if(record.isDelete) {
          _models.remove(record.id);
        } else {
          _models[record.id] = _build(record);
        }
      }
    } else {
      _dataFileSize = 0;
    }
    _dataSink = file.openWrite(mode: FileMode.writeOnlyAppend);
  }
  
  Future<void> _openSync() async {
    final file = File('$path.sync');
    if(await file.exists()) {
      final lines = await file.readAsLines();
      for(var line in lines) {
        print('sync $line');
        final record = SyncRecord.fromLine(line);
        if(_syncRecord == null) {
          _syncRecord = record;
        } else {
          _replicants[record.rid] = record;
        }
      }
    }
  }
  
  Future<void> flush() async {
    await _compactCompleter?.future;
    await _dataSink?.flush();
  }
  
  Future<void> close() async {
    await flush();
    await _dataSink?.close();
    _dataSink = null;
    _models.clear();
    _dataFileSize = 0;
    _syncRecord = null;
    _replicants.clear();
  }

  Future<void> destroy() async {
    await close();
    await _destroy(path);
    await _destroy('$path.init');
    await _destroy('$path.sync');
    await _destroy('$path.temp');
  }
  Future<void> _destroy(String path) => File(path).exists().then((e) => e ? File(path).delete() : null);

  Future<void> reset({String uid, Stream stream}) async {
    await destroy();
    if(uid != null) {
      final sink = File('$path.sync').openWrite(mode: FileMode.writeOnly);
      sink.writeln(SyncRecord(uid: uid, rid: ObjectId().hexString));
      await sink.flush();
      await sink.close();
    }
    if(stream != null) {
      final sink = File('$path.init').openWrite(mode: FileMode.writeOnly);
      await sink.addStream(stream);
      await sink.flush();
      await sink.close();
    }
    await open();
  }

  String newId() {
    return ObjectId().hexString;
  }

  T get<T extends DataModel>(String id, {T Function() orElse}) {
    if(_models.containsKey(id)) {
      return _models[id] as T;
    }
    return orElse?.call();
  }

  Iterable<T> getAll<T extends DataModel>() {
    return _models.values.whereType<T>();
  }

  List<T> batch<T extends DataModel>({Iterable<T> put, Iterable<String> remove}) {
    return _batch<T>(put: put, remove: remove);
  }
  List<T> _batch<T extends DataModel>({Iterable<T> put, Iterable<String> remove, bool notify = true}) {
    final results = <T>[];
    final records = <DataRecord>[];

    if(put != null) for(var model in put) {
      if(model.isSameAs(_models[model.id])) {
        results.add(model);
      } else {
        if(model.id.isBlank) {
          model = model.copyWith(id: newId());
        }
        _models[model.id] = model;
        results.add(model);
        records.add(DataRecord.fromModel(model));
      }
    }
    if(remove != null) for(var id in remove) {
      if(_models.containsKey(id)) {
        _models.remove(id);
        records.add(DataRecord.delete(id));
      }
    }

    if(records.isNotEmpty) {
      _commitRecords(records);
      if(notify) {
        _notify(records);
      }
      if(_needsCompact && isNotCompacting) {
        compact();
      }
    }

    return results;
  }
  
  T put<T extends DataModel>(T model) => batch(put: [model])[0];
  List<T> putAll<T extends DataModel>(Iterable<T> models) => batch(put: models);

  void remove(String id) => batch(remove: [id]);
  void removeAll(Iterable<String> ids) => batch(remove: ids);
  
  void _commitRecords(List<DataRecord> records) {
    _dataFileSize += records.length;
    if(isCompacting) {
      _dataBuffer.addAll(records);
    } else {
      for(var record in records) {
        _dataSink.writeln(record);
      }
    }
  }

  int get fileSize => _dataFileSize;
  int get percentObsolete => (size > 0) ? (100 * (fileSize - size) ~/ fileSize) : 0;
  int get size => _models.length;

  bool get isCompacting => _compactCompleter != null && !_compactCompleter.isCompleted;
  bool get isNotCompacting => !isCompacting;
  bool get _needsCompact => (size >= 6) && (percentObsolete >= 20);

  Future<void> compact() {
    _compactCompleter = Completer();
    _compact().then(_compactCompleter.complete);
    return _compactCompleter.future;
  }
  Future<void> _compact() async {
    _dataBuffer = [];
    _dataFileSize = size;
    final file = File('$path.temp');
    final sink = file.openWrite(mode: FileMode.writeOnly);
    for(var model in _models.values) {
      sink.writeln(DataRecord.fromModel(model));
    }
    await sink.flush();
    await sink.close();
    await _dataSink.flush();
    await _dataSink.close();
    _dataSink = (await file.rename(path)).openWrite(mode: FileMode.writeOnlyAppend);;
    for(var record in _dataBuffer) {
      _dataSink.writeln(record);
    }
    _dataBuffer = null;
    if(_needsCompact) {
      await _compact();
    }
  }

  SyncRecord _syncRecord;
  String get id => _syncRecord?.id;
  String get uid => _syncRecord?.uid;
  String get rid => _syncRecord?.rid;

  final _replicants = <String, SyncRecord>{};
  List<String> get replicants => _replicants.keys.toList(growable: false);
  
  Future<Stream<List<int>>> replicate() {
    _replicateCompleter = Completer<Stream<List<int>>>();
    _replicate().then(_replicateCompleter.complete);
    return _replicateCompleter.future;
  }
  Future<Stream<List<int>>> _replicate() async {
    assert(uid != null, 'cannot replicate a database that does not have its uid set');
    final rid = ObjectId().hexString;
    final file = File('$path.$rid');
    final sink = file.openWrite(mode: FileMode.writeOnly);
    sink.writeln('[sync]');
    sink.writeln(SyncRecord(uid: uid, rid: rid));
    sink.writeln('[data]');
    for(var model in _models.values) {
      sink.writeln(DataRecord.fromModel(model));
    }
    await sink.flush();
    await sink.close();
    final controller = StreamController<List<int>>();
    controller.addStream(file.openRead()).then((_) {
      _commitReplicant(rid);
      controller.close().then((_) => file.delete());
    });
    return controller.stream;
  }

  Future<void> _commitReplicant(String rid) async {
    _replicants[rid] = SyncRecord(uid: uid, rid: rid);
    final sink = File('$path.sync').openWrite(mode: FileMode.writeOnlyAppend);
    sink.writeln(_replicants[rid]);
    await sink.flush();
    await sink.close();
  }
  
  DataSocket _socket;
  DataSocket get socket => _socket;
  DataSocket createSocket(BaseWebSocket ws) => _socket = DataSocket(this, ws);

  Future<void> bind(DataSocket socket) async {
    assert(uid == socket._db.uid, 'cannot bind to a different user');
    this.socket.register(socket);
    print('sync start');
    await this.socket.sync(socket);
    print('sync end');
  }

  int lastSync(String rid) {
    return _replicants[rid].timestamp;
  }

  void _notify(List<DataRecord> records) {
    socket.add(DataSocketEvent({id}, records));
  }

  void _onAdd(List<DataRecord> records) => _batch(
    put: records.where((r) => r.isNotDelete).map((r) => _build(r)),
    remove: records.where((r) => r.isDelete).map((r) => r.id),
    notify: false
  );

  DataModel _build(DataRecord record) {
    assert(_builders[record.type] != null, 'no builder registered for ${record.type}');
    return _builders[record.type](record.data);
  }
}

abstract class DataModel extends JsonModel {
  final int timestamp;
  DataModel(String id) :
    timestamp = DateTime.now().millisecondsSinceEpoch,
    super(id)
  ;
  DataModel.fromJson(data) :
    timestamp = Json.field(data, 'timestamp'),
    super.fromJson(data)
  ;
  DataModel copyWith({String id});
  @override Map<String, dynamic> toJson() => super.toJson()
    ..['timestamp'] = timestamp
  ;
}

class DataRecord {

  final String id;
  final String type;
  final Map _data;
  DataRecord(this.id, [this.type, this._data]);
  
  factory DataRecord.delete(String id) {
    return DataRecord(id);
  }
  factory DataRecord.fromLine(String line) {
    // full: <id>:<type>{jsonData}
    // deleted: <id>
    final i1 = line.indexOf(':');
    final id = (i1 != -1) ? line.substring(0, i1) : line;
    if(i1 != -1) {
      final i2 = line.indexOf('{', i1 + 1);
      if(i2 != -1) {
        final type = line.substring(i1 + 1, i2);
        final data = Json.decode(line.substring(i2));
        return DataRecord(id, type, data);
      }
    }
    return DataRecord(id);
  }
  factory DataRecord.fromModel(DataModel model) {
    final data = model.toJson()..removeWhere((k,v) => v == null || (v is String && v.isEmpty) || (v is Iterable && v.isEmpty) || (v is Map && v.isEmpty));
    return DataRecord(model.id, model.runtimeType.toString(), data);
  }

  Map get data => _data..['id'] = id;

  bool get isDelete => (id != null) && ((type == null) || (_data == null));
  bool get isNotDelete => !isDelete;

  @override
  toString() => isDelete ? id : '$id:$type${Json.encode(_data..remove('id'))}';
}

class SyncRecord {
  final String uid;
  final String rid;
  final int timestamp;
  SyncRecord({this.uid, this.rid, int timestamp}) : timestamp = timestamp ?? DateTime.now().millisecondsSinceEpoch;
  factory SyncRecord.fromLine(String line) {
    final i1 = line.indexOf(':');
    final i2 = line.indexOf(':', i1 + 1);
    return SyncRecord(
      uid: line.substring(0, i1),
      rid: line.substring(i1 + 1, i2),
      timestamp: int.parse(line.substring(i2 + 1)),
    );
  }
  
  String get id => '$uid:$rid';

  @override
  String toString() => '$uid:$rid:$timestamp';
}

class DataSocket {

  final Database _db;
  final _sockets = <DataSocket>[];
  final BaseWebSocket _ws;
  DataSocket(this._db, this._ws) {
    _ws.on.put('/data', (event) async {
      print('onAdd');
      await onAdd(event.value);
    });
  }

  String get id => _db.id;

  Future<void> sync(DataSocket socket) async {
    final lastSync = _db.lastSync(socket._db.rid);

    final a = _db.getAll();
    final b = socket._db.getAll();
    final addToB = a.where((a) => !b.contains(a) && a.timestamp > lastSync).map((m) => DataRecord.fromModel(m));
    final removeFromA = b.where((b) => !a.contains(b) && b.timestamp < lastSync).map((m) => DataRecord.delete(m.id));
    final addToA = a.where((a) => !b.contains(a) && a.timestamp > lastSync).map((m) => DataRecord.fromModel(m));
    final removeFromB = b.where((b) => !a.contains(b) && b.timestamp < lastSync).map((m) => DataRecord.delete(m.id));

    final eventA = DataSocketEvent({socket.id}, [...addToA, ...removeFromA]);
    final eventB = DataSocketEvent({id}, [...addToB, ...removeFromB]);

    await onAdd(eventA);
    await add(eventB);
  }

  void register(DataSocket socket) {
    if(!_sockets.contains(socket)) {
      _sockets.add(socket);
      socket.register(this);
    }
  }
  void unregister(DataSocket socket) {
    socket.unregister(this);
    _sockets.remove(socket);
  }


  /// new records in db, notify others
  Future<void> add(DataSocketEvent event) {
    final futures = <Future<WsResult>>[];
    for(var socket in _sockets) {
      if(event.history.contains(socket.id) == false) {
        print('add');
        futures.add(_ws.put('/data', event));
      }
    }
    return Future.wait(futures);
  }
  
  /// new records from somewhere else, update db and then notify others
  Future<void> onAdd(DataSocketEvent event) {
    if(event.history.contains(id) == false) {
      event.history.add(id);
      _db._onAdd(event.records);
      return add(event);
    }
    return Future.value();
  }
}

class DataSocketEvent {
  final Set<String> history;
  final List<DataRecord> records;
  DataSocketEvent(this.history, this.records);
}