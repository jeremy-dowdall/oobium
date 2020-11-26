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
          _replicants.add(Replicant(this, record.rid));
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
      sink.writeln(SyncRecord(uid, ObjectId().hexString));
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
    final results = <T>[];
    final records = <DataRecord>[];
    final deletes = <DataModel>[];

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
      final model = _models.remove(id);
      if(model != null) {
        records.add(DataRecord.delete(id));
        deletes.add(model);
      }
    }

    if(records.isNotEmpty) {
      _commitRecords(records);
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
    for(var replicant in replicants) {
      replicant.add(records);
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

  final _replicants = <Replicant>[];
  List<Replicant> get replicants => _replicants;
  
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
    sink.writeln(SyncRecord(uid, rid));
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
    final replicant = Replicant(this, rid);
    final sink = File('$path.sync').openWrite(mode: FileMode.writeOnlyAppend);
    sink.writeln(replicant);
    await sink.flush();
    await sink.close();
    _replicants.add(replicant);
  }
  
  Future<void> bind(WebSocket socket) async {
    final rid = (await socket.get('/id')).data as String;

    final replicant = _replicants.firstWhere((r) => r.id == rid, orElse: () => null);
    assert(replicant != null, 'no replicant found with id $rid');

    await replicant.connect(socket);
    await replicant.sync();
  }

  void _batch(List<DataRecord> records) => batch(
    put: records.where((r) => r.isNotDelete).map((r) => _build(r)),
    remove: records.where((r) => r.isDelete).map((r) => r.id)
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
  final int timestamp;
  final Map _data;
  DataRecord(this.id, this.timestamp, [this.type, this._data]);
  
  factory DataRecord.delete(String id) {
    return DataRecord(id, DateTime.now().millisecondsSinceEpoch); // ~time of deletion
  }
  factory DataRecord.fromLine(String line) {
    // deleted: <id>:<timestamp>
    // full: <id>:<timestamp>:<type>{jsonData}
    final i1 = line.indexOf(':');
    final i2 = line.indexOf(':', i1 + 1);
    final id = line.substring(0, i1);
    final timestamp = int.parse(line.substring(i1 + 1, (i2 != -1) ? i2 : null));
    if(i2 != -1) {
      final i3 = line.indexOf('{', i1 + 1);
      final type = line.substring(i1 + 1, i3);
      final data = Json.decode(line.substring(i3));
      return DataRecord(id, timestamp, type, data);
    }
    return DataRecord(id, timestamp);
  }
  factory DataRecord.fromModel(DataModel model) {
    final data = model.toJson()
      ..removeWhere((k,v) => (k == 'id') || (k == 'timestamp') || (v == null) || (v is String && v.isEmpty) || (v is Iterable && v.isEmpty) || (v is Map && v.isEmpty));
    return DataRecord(model.id, model.timestamp, model.runtimeType.toString(), data);
  }

  Map get data => {..._data, 'id': id, 'timestamp': timestamp};

  bool get isDelete => (type == null);
  bool get isNotDelete => !isDelete;

  @override
  toString() => isDelete ? id : '$id:$type${Json.encode(_data)}';
}

class SyncRecord {
  final String uid;
  final String rid;
  SyncRecord(this.uid, this.rid);
  factory SyncRecord.fromLine(String line) {
    final i1 = line.indexOf(':');
    final i2 = line.indexOf(':', i1 + 1);
    return SyncRecord(line.substring(0, i1), line.substring(i1 + 1, i2));
  }
  
  String get id => '$uid:$rid';

  @override
  String toString() => '$uid:$rid';
}

class Replicant {

  final Database db;
  final String rid;
  final File file;
  Replicant(this.db, this.rid) : file = File('${db.path}.sync.$rid');

  String get id => '$uid:$rid';
  String get uid => db.uid;
  int lastSync;

  WebSocket _socket;
  Future<void> connect(WebSocket socket) async {
    _socket = socket;
    await stopTracking();
    _socket.on.put('/data', (data) => onAdd(DataEvent.fromJson(data)));
  }
  Future<void> disconnect() async {
    _socket.remove.on.put('/data', (data) => onAdd(DataEvent.fromJson(data)));
    _socket = null;
    await startTracking();
  }

  bool get isConnected => _socket != null;
  bool get isNotConnected => !isConnected;

  IOSink _sink;
  Future<void> startTracking() async {
    _sink ??= file.openWrite(mode: FileMode.writeOnlyAppend);
  }
  Future<void> stopTracking() async {
    await _sink?.flush();
    await _sink?.close();
    _sink = null;
  }

  Future<void> sync() async {
    assert(isConnected, 'cannot sync unless connected to a socket');

    final lines = await file.readAsLines();
    final lastSync = int.parse(lines[0]);
    final b = await getRecordsSince(lastSync);

    final aAdds = db.getAll().where((m) => m.timestamp > lastSync); // everything added since last sync
    final aDels = lines.skip(1).map((l) => DataRecord.fromLine(l)); // everything deleted since last sync
    final bAdds = b.where((r) => r.isNotDelete);
    final bDels = b.where((r) => r.isDelete);

    // final addToB = a.where((a) => !b.contains(a) && a.timestamp > lastSync).map((m) => DataRecord.fromModel(m));
    // final removeFromA = b.where((b) => !a.contains(b) && b.timestamp < lastSync).map((m) => DataRecord.delete(m.id));
    // final addToA = a.where((a) => !b.contains(a) && a.timestamp > lastSync).map((m) => DataRecord.fromModel(m));
    // final removeFromB = b.where((b) => !a.contains(b) && b.timestamp < lastSync).map((m) => DataRecord.delete(m.id));

    await onAdd(DataEvent({id}, [...addToA, ...removeFromA]));
    await add([...addToB, ...removeFromB]);
  }

  /// new records in db, notify the socket
  void add(List<DataRecord> records) {
    if(isConnected) {
      _socket.put('/data', DataEvent({db.id}, records));
      file.writeAsString(DateTime.now().millisecondsSinceEpoch.toString());
    } else {
      for(var record in records.where((r) => r.isDelete)) {
        _sink.writeln('${record.id}:${record.timestamp}');
      }
    }
  }

  Future<Iterable<DataRecord>> getRecordsSince(int lastSync) async {
    final result = await _socket.get('/data/$lastSync');
    return result.data.map((e) => DataRecord.fromLine(e));
  }

  /// new records from somewhere else, update db and then notify others
  Future<void> onAdd(DataEvent event) async {
    if(event.visit(id)) {
      db._batch(event.records);
      await Future.wait(db.replicants.map((r) => r.onAdd(event)));
    }
  }

  @override
  String toString() => SyncRecord(uid, rid).toString();
}

class DataEvent extends Json {

  final Set<String> history;
  final List<DataRecord> records;

  DataEvent(this.history, this.records);
  DataEvent.fromJson(data) :
    history = (data['history'] as Map).keys.toSet(),
    records = (data['records'] as List).map((e) => DataRecord.fromLine(e))
  ;

  bool hasVisited(String id) => history.contains(id);
  bool hasNotVisited(String id) => !hasVisited(id);

  bool visit(String id) {
    final visited = history.contains(id);
    history.add(id);
    return !visited;
  }

  @override
  Map<String, dynamic> toJson() => {
    'history': { for(var id in history) id: true },
    'records': records.map((r) => r.toString()).toList()
  };
}