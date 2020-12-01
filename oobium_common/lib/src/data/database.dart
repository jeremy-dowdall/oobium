import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:objectid/objectid.dart';
import 'package:oobium_common/src/json.dart';
import 'package:oobium_common/src/string.extensions.dart';
import 'package:oobium_common/src/websocket/websocket.dart';

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
          if(line.startsWith('[') && line.endsWith(']')) {
            await sink?.flush();
            await sink?.close();
            sink = null;
            section = line.substring(1, line.length - 1).trim();
          }
          else if(section == 'sync') {
            final record = SyncRecord.fromLine(line);
            if(sink == null) {
              sink = File('$path.sync').openWrite(mode: FileMode.writeOnly);
            } else {
              await File('$path.sync.${record.rid}').writeAsString(DateTime.now().millisecondsSinceEpoch.toString());
            }
            sink.writeln(record);
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
        final record = SyncRecord.fromLine(line);
        if(_self == null) {
          _self = record;
        } else {
          final replicant = Replicant(this, record.rid);
          await replicant.open();
          _replicants.add(replicant);
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
    _self = null;
    for(var replicant in _replicants) replicant.close();
    _replicants.clear();
    for(var socket in _binders) socket.finish();
    _binders.clear();
  }

  Future<void> destroy() async {
    await close();
    await _destroy(path);
    await _destroy('$path.init');
    await _destroy('$path.sync');
    await _destroy('$path.temp');
    await Future.wait(replicants.map((r) => r.destroy()));
  }
  Future<void> _destroy(String path) => File(path).exists().then((e) => e ? File(path).delete() : null);

  Future<void> reset({String uid, Stream stream, WebSocket socket}) async {
    await destroy();
    if(socket != null) {
      stream = (await socket.get('/db/replicate', retry: true)).data as Stream<List<int>>;
    }
    if(stream != null) {
      final sink = File('$path.init').openWrite(mode: FileMode.writeOnly);
      await sink.addStream(stream);
      await sink.flush();
      await sink.close();
    }
    if(uid != null) {
      final sink = File('$path.sync').openWrite(mode: FileMode.writeOnly);
      sink.writeln(SyncRecord(uid, ObjectId().hexString));
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
    return _batch(put: put, remove: remove, notify: true);
  }
  List<T> _batch<T extends DataModel>({Iterable<T> put, Iterable<String> remove, bool notify}) {
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
      final model = _models.remove(id);
      if(model != null) {
        records.add(DataRecord.delete(id));
      }
    }

    if(records.isNotEmpty) {
      _commitRecords(records, notify);
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
  
  void _commitRecords(List<DataRecord> records, bool notify) {
    _dataFileSize += records.length;
    if(isCompacting) {
      _dataBuffer.addAll(records);
    } else {
      for(var record in records) {
        _dataSink.writeln(record);
      }
    }
    if(notify) {
      for(var replicant in replicants) {
        replicant.add(records);
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

  SyncRecord _self;
  String get id => _self?.id;
  String get uid => _self?.uid;
  String get rid => _self?.rid;

  final _binders = <Binder>[];
  List<Binder> get binders => [..._binders];
  final _replicants = <Replicant>[];
  List<Replicant> get replicants => [..._replicants];
  
  Future<Stream<List<int>>> replicate() {
    _replicateCompleter = Completer<Stream<List<int>>>();
    _replicate().then(_replicateCompleter.complete);
    return _replicateCompleter.future;
  }
  Future<Stream<List<int>>> _replicate() async {
    assert(uid != null, 'cannot replicate a database that does not have its uid set');
    final rid = ObjectId().hexString;
    assert(replicants.any((r) => r.rid == rid) == false, 'duplicate replicant id (rid)');
    final file = File('$path.init.$rid');
    final sink = file.openWrite(mode: FileMode.writeOnly);
    sink.writeln('[sync]');
    sink.writeln(SyncRecord(uid, rid));
    sink.writeln(SyncRecord(uid, this.rid));
    sink.writeln('[data]');
    for(var model in _models.values) {
      sink.writeln(DataRecord.fromModel(model));
    }
    await sink.flush();
    await sink.close();
    await _commitReplicant(rid);
    final controller = StreamController<List<int>>();
    controller.addStream(file.openRead()).then((_) {
      controller.close().then((_) => file.delete());
    });
    return controller.stream;
  }

  Future<void> _commitReplicant(String rid) async {
    final lastSync = DateTime.now().millisecondsSinceEpoch;
    final replicant = Replicant(this, rid, lastSync);
    await File('$path.sync.$rid').writeAsString(lastSync.toString());
    final sink = File('$path.sync').openWrite(mode: FileMode.writeOnlyAppend);
    sink.writeln(replicant);
    await sink.flush();
    await sink.close();
    _replicants.add(replicant);
  }
  
  Future<void> bind(WebSocket socket) {
    final binder = Binder(this, socket);
    _binders.add(binder);
    binder.finished.then((_) => _binders.remove(binder));
    return binder.ready;
  }

  void _onPut(List<DataRecord> records) => _batch(
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
  DataModel(String id) : timestamp = DateTime.now().millisecondsSinceEpoch, super(id) {
    assert(id == null || !id.contains(':'), 'invalid character ":" in id (pos ${id.indexOf(':')} of "$id")');
  }
  DataModel.fromJson(data) :
    timestamp = Json.field(data, 'timestamp'),
    super.fromJson(data)
  ;
  DataModel copyWith({String id});
  @override Map<String, dynamic> toJson() => super.toJson()
    ..['timestamp'] = timestamp
  ;
}

class DataRecord implements JsonString {

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
      final i3 = line.indexOf('{', i2 + 1);
      final type = line.substring(i2 + 1, i3);
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
  String toJsonString() => toString();

  @override
  toString() => isDelete ? '$id:$timestamp' : '$id:$timestamp:$type${Json.encode(_data)}';
}

class SyncRecord implements JsonString {
  final String uid;
  final String rid;
  SyncRecord(this.uid, this.rid);
  factory SyncRecord.fromLine(String line) {
    final i1 = line.indexOf(':');
    return SyncRecord(line.substring(0, i1), line.substring(i1 + 1));
  }
  
  String get id => '$uid:$rid';

  @override
  String toJsonString() => id;

  @override
  String toString() => id;
}

class Replicant {

  final Database db;
  final String rid;
  final File file;
  Replicant(this.db, this.rid, [int lastSync]) : file = File('${db.path}.sync.$rid') {
    _lastSync = lastSync;
  }

  String get uid => db.uid;

  int _lastSync;
  Future<void> open() async {
    final lines = await file.readAsLines();
    _lastSync = int.parse(lines[0]);
  }
  Future<void> close() {
    _binder?.detach();
    return stopTracking();
  }
  Future<void> destroy() async {
    await close();
    await file.delete();
  }

  Binder _binder;
  Future<void> attach(Binder binder) async {
    _binder = binder..attach(this);
    await stopTracking();
  }
  Future<void> detach() async {
    await startTracking();
    _binder.detach();
    _binder = null;
  }

  bool get isConnected => _binder != null;
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
    final a = await getSyncRecords();
    final b = await _binder.getSyncRecords();
    if(b.isNotEmpty) put(DataEvent({_binder.rid}, b));
    if(a.isNotEmpty) await add(a);
  }

  /// new records in db, notify the socket or save relevant records for a future sync
  Future<void> add(List<DataRecord> records) async {
    _lastSync = DateTime.now().millisecondsSinceEpoch;
    if(records.isNotEmpty) {
      if(isConnected) {
        await _binder.add(DataEvent({db.rid}, records));
        await file.writeAsString(_lastSync.toString());
      } else {
        for(var record in records.where((r) => r.isDelete)) {
          _sink.writeln('${record.id}:${record.timestamp}');
        }
      }
    }
  }

  /// new records from somewhere else, update db and then notify others (only happens when connected)
  void put(DataEvent event) {
    if(event.isNotEmpty && event.visit(db.rid, _lastSync)) {
      db._onPut(event.records);
      for(var r in db.replicants) {
        if(event.notVisitedBy(r.rid)) {
          r._binder.add(event);
        }
      }
    } else {
    }
  }
  
  Future<Iterable<DataRecord>> getSyncRecords() async {
    final lines = await file.readAsLines();
    final lastSync = int.parse(lines[0]);
    return [
      ...db.getAll().where((m) => m.timestamp > lastSync).map((m) => DataRecord.fromModel(m)),
      ...lines.skip(1).map((l) => DataRecord.fromLine(l)),
    ];
  }

  @override
  String toString() => SyncRecord(uid, rid).toString();
}

class Binder {
  final Database _db;
  final WebSocket _socket;
  final String replicatePath;
  final String connectPath;
  final String syncPath;
  final String dataPath;
  final _ready = Completer();
  final _finished = Completer();
  Binder(this._db, this._socket, {
    this.replicatePath = '/db/replicate',
    this.connectPath = '/db/connect',
    this.syncPath = '/db/sync',
    this.dataPath = '/db/data',
  }) {
    _socket.done.then((_) => finish());
    _subscriptions.addAll([
      _socket.on.put(connectPath, (req, res) => onConnect(req.data.value)),
      _socket.on.get(replicatePath, (req, res) async => res.send(data: await _db.replicate())),
    ]);
    sendConnect();
  }

  bool get isConnected => _replicant != null;
  bool isPeerConnected = false;
  Future<void> sendConnect() async {
    if(rid != null && !isPeerConnected) {
      isPeerConnected = (await _socket.put(connectPath, rid, retry: true)).isSuccess;
    }
    await readyCheck();
  }

  Future<void> onConnect(String rid) async {
    await _db._replicants.firstWhere((r) => r.rid == rid, orElse: () => null)?.attach(this);
    await readyCheck();
  }

  Future<void> readyCheck() async {
    if(isConnected && isPeerConnected) {
      final sync = rid.compareTo(_replicant.rid) > 0;
      if(sync) await _replicant.sync();
      _ready.complete();
    }
  }

  Future<void> get ready => _ready.future;
  Future<void> get finished => _finished.future;
  String get rid => _db.rid;

  Replicant _replicant;
  final _subscriptions = <WsSubscription>[];
  final _rSubscriptions = <WsSubscription>[];
  void attach(Replicant replicant) {
    _replicant = replicant;
    _rSubscriptions.addAll([
      _socket.on.put(dataPath, (req, res) => replicant.put(DataEvent.fromJson(req.data.value))),
      // _socket.on.put(syncPath, (data) => replicant.sync().then((_) => _ready.complete())),
      _socket.on.get(syncPath, (req, res) async => res.send(data: await replicant.getSyncRecords())),
    ]);
  }
  void detach() {
    for(var s in _rSubscriptions) s.cancel();
    _rSubscriptions.clear();
    _replicant = null;
  }
  Future<void> finish() async {
    for(var s in _subscriptions) s.cancel();
    _subscriptions.clear();
    await _replicant?.detach();
    if(!_finished.isCompleted) _finished.complete();
  }
  
  Future<bool> add(DataEvent event) async {
    return (await _socket.put(dataPath, event)).isSuccess;
  }

  Future<Iterable<DataRecord>> getSyncRecords() async {
    final result = await _socket.get(syncPath);
    return (result.data as List).map((e) => DataRecord.fromLine(e)).toList();
  }
}

class DataEvent extends Json {

  final Set<String> history;
  final List<DataRecord> records;
  final int timestamp;

  DataEvent(this.history, this.records) : timestamp = DateTime.now().millisecondsSinceEpoch;
  DataEvent.fromJson(data) :
    history = Json.toSet(data, 'history'),
    records = Json.toList(data, 'records', (e) => DataRecord.fromLine(e)),
    timestamp = Json.field(data, 'timestamp')
  ;

  bool visitedBy(String id) => history.contains(id);
  bool notVisitedBy(String id) => !visitedBy(id);

  bool get isEmpty => records.isEmpty;
  bool get isNotEmpty => !isEmpty;

  bool visit(String id, int lastSync) {
    final notVisited = notVisitedBy(id);
    history.add(id);
    return notVisited && (timestamp > lastSync);
  }

  @override
  Map<String, dynamic> toJson() => {
    'history':   Json.from(history),
    'records':   Json.from(records),
    'timestamp': Json.from(timestamp)
  };

  @override
  String toString() => 'DataEvent(history: $history, records: $records, timestamp: $timestamp)';
}