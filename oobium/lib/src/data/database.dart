import 'dart:async';
import 'dart:io';

import 'package:objectid/objectid.dart';
import 'package:oobium/src/json.dart';
import 'package:oobium/src/websocket.dart';

class Database {

  final String path;
  Database(this.path, [List<Function(Map data)> builders]) {
    if(builders != null) for(var builder in builders) {
      final type = builder.runtimeType.toString().split(' => ')[1];
      _builders[type] = builder;
    }
  }

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
    await _openSync();
    await _openData();
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
              await File('$path.sync.${record.id}').writeAsString(DateTime.now().millisecondsSinceEpoch.toString());
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
      if(lines.length > 0) {
        _id = lines[0];
        for(var replicant in lines.skip(1).map((id) => Replicant(id, path))) {
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
    _id = null;
    for(var replicant in _replicants) replicant.close();
    _replicants.clear();
    for(var socket in _binders.values) socket.cancel();
    _binders.clear();
  }

  Future<void> destroy() async {
    await _destroy('$path.init');
    await _destroy('$path.sync');
    await _destroy('$path.temp');
    await Future.wait(_replicants.map((r) => r.destroy()));
    await close();
    await _destroy(path);
  }
  Future<void> _destroy(String path) => File(path).exists().then((e) => e ? File(path).delete() : null);

  Future<void> reset({Stream stream, WebSocket socket}) async {
    await destroy();
    if(socket != null) {
      stream = (await socket.get(Binder.replicatePath, retry: true)).data as Stream<List<int>>;
    }
    if(stream != null) {
      final sink = File('$path.init').openWrite(mode: FileMode.writeOnly);
      await sink.addStream(stream);
      await sink.flush();
      await sink.close();
    }
    await open();
  }

  T get<T extends DataModel>(String id, {T Function() orElse}) {
    if(_models.containsKey(id)) {
      return _models[id] as T;
    }
    return orElse?.call();
  }

  Iterable<T> getAll<T extends DataModel>() {
    return (T == DataModel) ? _models.values : _models.values.whereType<T>();
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
        // if(model.id.isBlank) {
        //   model = model.copyWith(id: newId());
        // }
        _models[model.id] = model;
        results.add(model);
        records.add(DataRecord.fromModel(model));
      }
      for(var member in model._fields.models) {
        if(member.isNotSameAs(_models[member.id])) {
          _models[member.id] = member;
          records.add(DataRecord.fromModel(member));
        }
      }
    }
    if(remove != null) for(var id in remove) {
      final model = _models.remove(id);
      results.add(model);
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

  T remove<T extends DataModel>(String id) => batch(remove: [id])[0];
  List<T> removeAll<T extends DataModel>(Iterable<String> ids) => batch(remove: ids);
  
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
      for(var replicant in _replicants) {
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

  String _id;
  String get id => _id;

  final _binders = <WebSocket, Binder>{};
  final _replicants = <Replicant>[];

  Future<Stream<List<int>>> replicate() {
    _replicateCompleter = Completer<Stream<List<int>>>();
    _replicate().then(_replicateCompleter.complete);
    return _replicateCompleter.future;
  }
  Future<Stream<List<int>>> _replicate() async {
    if(_id == null) {
      _id = ObjectId().hexString;
      await File('$path.sync').writeAsString('$_id\n', flush: true);
    }
    final replicant = Replicant(ObjectId().hexString, path, DateTime.now().millisecondsSinceEpoch);
    assert(_replicants.any((r) => r.id == replicant.id) == false, 'duplicate replicant ($replicant)');
    final file = File('$path.init.${replicant.id}');
    final sink = file.openWrite(mode: FileMode.writeOnly);
    sink.writeln('[sync]');
    sink.writeln(SyncRecord(replicant.id));
    sink.writeln(SyncRecord(this.id));
    sink.writeln('[data]');
    for(var model in _models.values) {
      sink.writeln(DataRecord.fromModel(model));
    }
    await sink.flush();
    await sink.close();
    await _commitReplicant(replicant);
    final controller = StreamController<List<int>>();
    controller.addStream(file.openRead()).then((_) {
      controller.close().then((_) => file.delete());
    });
    return controller.stream;
  }

  Future<void> _commitReplicant(Replicant replicant) async {
    await File('$path.sync.${replicant.id}').writeAsString(replicant.lastSync.toString());
    await File('$path.sync').writeAsString('$replicant\n', mode: FileMode.append, flush: true);
    _replicants.add(replicant);
  }
  
  Future<void> bind(WebSocket socket) {
    if(_binders.containsKey(socket)) {
      return Future.value();
    } else {
      final binder = Binder(this, socket);
      _binders[socket] = binder;
      binder.finished.then((_) => _binders.remove(socket));
      return binder.ready;
    }
  }

  Future<void> unbind(WebSocket socket) {
    final binder = _binders.remove(socket);
    return (binder != null) ? binder.cancel() : Future.value();
  }

  void _onPut(List<DataRecord> records) => _batch(
    put: records.where((r) => r.isNotDelete).map((r) => _build(r)),
    remove: records.where((r) => r.isDelete).map((r) => r.id),
    notify: false
  );

  DataModel _build(DataRecord record) {
    assert(_builders[record.type] != null, 'no builder registered for ${record.type}');
    final value = _builders[record.type](record.data);
    assert(value is DataModel, 'builder did not return a DataModel: $value');
    return (value as DataModel).._fields._db = this;
  }
}

abstract class DataModel extends JsonModel implements DataId {

  final int timestamp;
  final DataFields _fields;

  DataModel(Map<String, dynamic> fields) :
      timestamp = DateTime.now().millisecondsSinceEpoch,
      _fields = DataFields(fields),
      super(ObjectId().hexString);

  DataModel.copyNew(DataModel original, Map<String, dynamic> fields) :
    timestamp = DateTime.now().millisecondsSinceEpoch,
    _fields = DataFields({...original._fields._map}..addAll(fields??{})),
    super(ObjectId().hexString);

  DataModel.copyWith(DataModel original, Map<String, dynamic> fields) :
    timestamp = DateTime.now().millisecondsSinceEpoch,
    _fields = DataFields({...original._fields._map}..addAll(fields??{})),
    super(original.id);

  DataModel.fromJson(data, Set<String> fields, Set<String> modelFields) :
    timestamp = Json.field(data, 'timestamp'),
    _fields = DataFields({
      for(var k in fields) k: Json.field(data, k),
      for(var k in modelFields) k: DataId(Json.field(data, k))
    }),
    super.fromJson(data);

  dynamic operator [](String key) => _fields[key];

  DataModel copyNew();
  DataModel copyWith();

  DateTime get createdAt => ObjectId.fromHexString(id).timestamp;
  DateTime get updatedAt => DateTime.fromMillisecondsSinceEpoch(timestamp);

  @override
  bool isSameAs(other) =>
      (runtimeType == other?.runtimeType) &&
      (id == other.id) && (timestamp == other.timestamp) &&
      _fields == other._fields;

  @override
  bool isNotSameAs(other) => !isSameAs(other);

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'timestamp': timestamp,
    for(var e in _fields._map.entries) e.key: e.value
  };

  @override
  String toString() => '${runtimeType.toString()}($id)';
}

class DataId implements JsonString {
  final String id;
  DataId(this.id);
  @override
  String toJsonString() => id;
}

class DataFields {

  final Map<String, dynamic> _map;
  DataFields(this._map);

  Database _db;

  Iterable<DataModel> get models => _map.values.whereType<DataModel>();

  operator [](String key) {
    final value = _map[key];
    if(value is DataModel) return value;
    if(value is DataId) return _db.get(value.id);
    return value;
  }

  bool operator ==(other) => (other is DataFields) && (_map.length == other._map.length) && _map.keys.every((k) => _(k) == other._(k));

  String _(String key) {
    final obj = _map[key];
    if(obj is DataId) return obj.id;
    return obj;
  }
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

/// TODO obsolete?
class SyncRecord implements JsonString {
  final String id; // replicant id
  SyncRecord(this.id);
  factory SyncRecord.fromLine(String line) {
    return SyncRecord(line);
  }
  
  @override
  String toJsonString() => id;

  @override
  String toString() => id;
}

class Replicant {

  final String id;
  final File file;
  Replicant(this.id, String dbpath, [int lastSync]) : file = File('$dbpath.sync.$id') {
    _lastSync = lastSync;
  }

  int _lastSync;
  int get lastSync => _lastSync;

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
    _binder = binder;
    await stopTracking();
  }
  Future<void> detach() async {
    await startTracking();
    _binder?.detach();
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

  /// new records in db, notify the socket or save relevant records for a future sync
  Future<void> add(List<DataRecord> records) async {
    _lastSync = DateTime.now().millisecondsSinceEpoch;
    if(records.isNotEmpty) {
      if(isConnected) {
        await _binder.sendData(records);
        await file.writeAsString(_lastSync.toString());
      } else {
        for(var record in records.where((r) => r.isDelete)) {
          _sink.writeln(record);
        }
      }
    }
  }

  Future<Iterable<DataRecord>> getSyncRecords(Iterable<DataModel> models) async {
    final lines = await file.readAsLines();
    final lastSync = int.parse(lines[0]);
    return [
      ...models.where((m) => m.timestamp > lastSync).map((m) => DataRecord.fromModel(m)),
      ...lines.skip(1).map((l) => DataRecord.fromLine(l)),
    ];
  }

  @override
  String toString() => id;
}

class Binder {

  static const replicatePath = '/db/replicate';
  static const connectPath = '/db/connect';
  static const syncPath = '/db/sync';
  static const dataPath = '/db/data';

  final Database _db;
  final WebSocket _socket;
  final _ready = Completer();
  final _finished = Completer();
  final _subscriptions = <WsSubscription>[];
  Replicant _replicant;
  Binder(this._db, this._socket) {
    _socket.done.then((_) => cancel());
    _subscriptions.addAll([
      _socket.on.get(replicatePath, (req, res) async => res.send(data: await _db.replicate())),
      _socket.on.put(connectPath, (req, res) => onConnect(req.data)),
      _socket.on.put(dataPath, (req, res) => onData(req.data)),
      _socket.on.put(syncPath, (req, res) async => onSync(req.data)),
    ]);
    sendConnect();
  }

  String localId;
  String get remoteId => _replicant.id;

  bool isConnected = false;
  bool isPeerConnected = false;
  bool isSynced = false;
  bool isPeerSynced = false;

  Future<void> sendConnect() async {
    localId = _db.id;
    if(localId != null && !isPeerConnected) {
      isPeerConnected = (await _socket.put(connectPath, localId, retry: true)).isSuccess;
    }
    await syncCheck();
  }

  Future<void> onConnect(WsData data) async {
    final rid = data.value as String;
    final replicant = _db._replicants.firstWhere((r) => r.id == rid, orElse: () => null);
    assert(replicant != null, 'no replicant found with id $rid');
    await attach(replicant);
    isConnected = _replicant != null;
    if(localId == null) await sendConnect();
    else await syncCheck();
  }
  
  Future<void> syncCheck() async {
    if(isConnected && isPeerConnected) {
      await sendSync();
    }
  }

  Future<void> sendSync() async {
    if(isConnected && isPeerConnected && !isPeerSynced) {
      final records = await _replicant.getSyncRecords(_db.getAll());
      isPeerSynced = (await _socket.put(syncPath, records)).isSuccess;
    }
    readyCheck();
  }

  Future<void> onSync(data) async {
    isSynced = true;
    final records = (data.value as List).map((e) => DataRecord.fromLine(e)).toList();
    final event = DataEvent({remoteId}, records);
    await onData(event);
    await sendSync();
  }

  Future<void> readyCheck() async {
    if(isConnected && isPeerConnected && isSynced && isPeerSynced) {
      _ready.complete();
    }
  }

  /// new local records -> send them out via put(dataPath, event)
  Future<bool> sendData(data) async {
    final event = (data is DataEvent) ? data : (data is List<DataRecord>) ? DataEvent({localId}, data) : null;
    if(event != null && event.isNotEmpty) {
      return (await _socket.put(dataPath, event)).isSuccess;
    }
    return true; // nothing to do
  }

  /// new remote records -> update local db and then notify other binders (with same event)
  Future<void> onData(data) async {
    final event = (data is DataEvent) ? data : (data is WsData) ? DataEvent.fromJson(data.value) : null;
    if(event != null && event.isNotEmpty && event.visit(localId)) {
      _db._onPut(event.records);
      for(var binder in _db._binders.values) {
        if(event.notVisitedBy(binder.remoteId)) {
          await binder.sendData(event);
        }
      }
    }
  }

  Future<void> get ready => _ready.future;
  Future<void> get finished => _finished.future;

  Future<void> attach(Replicant replicant) async {
    _replicant = replicant;
    await _replicant?.attach(this);
  }
  Future<void> detach() async {
    await _replicant?.detach();
    _replicant = null;
  }
  Future<void> cancel() async {
    for(var s in _subscriptions) s.cancel();
    _subscriptions.clear();
    await _replicant?.detach();
    if(!_finished.isCompleted) _finished.complete();
  }
}

class DataEvent extends Json {

  final Set<String> history;
  final List<DataRecord> records;

  DataEvent(this.history, this.records);
  DataEvent.fromJson(data) :
    history = Json.toSet(data, 'history'),
    records = Json.toList(data, 'records', (e) => DataRecord.fromLine(e))
  ;

  bool visitedBy(String id) => history.contains(id);
  bool notVisitedBy(String id) => !visitedBy(id);

  bool get isEmpty => records.isEmpty;
  bool get isNotEmpty => !isEmpty;

  bool visit(String id) {
    final notVisited = notVisitedBy(id);
    history.add(id);
    return notVisited;
  }

  @override
  Map<String, dynamic> toJson() => {
    'history':   Json.from(history),
    'records':   Json.from(records),
  };

  @override
  String toString() => 'DataEvent(history: $history, records: $records)';
}