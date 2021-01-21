import 'dart:async';
import 'dart:convert';

import 'package:objectid/objectid.dart';
import 'package:oobium/src/data/data.dart';
import 'package:oobium/src/data/executor.dart';
import 'package:oobium/src/data/models.dart';
import 'package:oobium/src/data/repo.dart';
import 'package:oobium/src/database.dart';
import 'package:oobium/src/json.dart';
import 'package:oobium/src/websocket.dart';

import 'sync_base.dart'
  if (dart.library.io) 'sync_io.dart'
  if (dart.library.html) 'sync_html.dart' as platform;

String replicantPath([String name]) => (name != null) ? '/db/$name/replicant' : '/db/replicant';
String connectPath([String name]) => (name != null) ? '/db/$name/connect' : '/db/connect';
String syncPath([String name]) => (name != null) ? '/db/$name/sync' : '/db/sync';
String dataPath([String name]) => (name != null) ? '/db/$name/data' : '/db/data';

class Sync implements Connection {

  final Data db;
  final Models models;
  final Repo repo;
  Sync(this.db, this.repo, [this.models]);

  String id;
  final binders = <String, Binder>{};
  final replicants = <platform.Replicant>[];

  Future<Sync> open() => throw UnsupportedError('platform not supported');

  Future<void> flush() async {
    for(var replicant in replicants) {
      await replicant.flush();
    }
    await repo.flush();
  }
  
  Future<void> close() async {
    for(var binder in binders.values) {
      binder.cancel();
    }
    binders.clear();
    for(var replicant in replicants) {
      await replicant.close();
    }
    replicants.clear();
    id = null;
  }

  Future<void> save() => throw UnsupportedError('platform not supported');

  void put(Iterable<DataRecord> records) {
    repo.putAll(records);
    for(var replicant in replicants) {
      replicant.putAll(records);
    }
  }

  bool get isBound => binders.isNotEmpty;
  bool get isNotBound => !isBound;

  Future<void> bind(WebSocket socket, {String name, bool wait = true}) async {
    final key = _key(socket, name);
    if(binders.containsKey(key)) {
      return wait ? binders[key].ready : Future.value();
    } else {
      if(id == null) {
        id = ObjectId().hexString;
        await save();
      }
      // print('localId: $id');
      final binder = Binder(this, socket, name);
      binders[key] = binder;
      print('binders: $binders');
      binder.finished.then((_) => binders.remove(key));
      return wait ? binder.ready : Future.value();
    }
  }

  void unbind(WebSocket socket, {String name}) {
    binders.remove(_key(socket, name))?.cancel();
  }

  String _key(WebSocket socket, String name) => (name != null) ? '${socket?.hashCode}:$name' : '${socket?.hashCode}';

  Future<void> replicate(WebSocket socket) async {
    await _getReplicant(socket: socket);
    await _getReplicantData(socket);
  }
  Future<Replicant> _getReplicant({String rid, WebSocket socket}) async {
    if(rid != null) {
      final replicant = replicants.firstWhere((r) => r.id == rid, orElse: () => null);
      if(replicant == null) {
        return _addReplicant(rid);
      } else {
        return Future.value(replicant);
      }
    }
    if(socket != null) {
      final result = await socket.get(replicantPath(), retry: true);
      if(result.isSuccess) {
        final response = result.data.split(':');
        assert(id == null);
        id = response[1]; // TODO assert this is null to begin with?
        return _addReplicant(response[0]);
      }
    }
    throw Exception('could not get replicant');
  }
  Future<void> _getReplicantData(WebSocket socket) async {
    final result = await socket.get(dataPath(), retry: true);
    if(result.isSuccess && result is WsStreamResult) {
      await repo.put(result.data.transform(utf8.decoder).map((s) => DataRecord.fromLine(s)));
    }
  }

  Future<String> createReplicant() async {
    id ??= ObjectId().hexString;
    final replicant = await _addReplicant();
    return '$id:${replicant.id}';
  }

  Future<platform.Replicant> _addReplicant([String id]) async {
    final replicant = platform.Replicant(db, id ?? ObjectId().hexString);
    await replicant.open();
    replicants.add(replicant);
    await save();
    return replicant;
  }
}

class Binder {

  final Sync _sync;
  final WebSocket _socket;
  final String _name;
  final _ready = Completer();
  final _finished = Completer();
  final _subscriptions = <WsSubscription>[];
  platform.Replicant _replicant;
  Binder(this._sync, this._socket, this._name) {
    _socket.ready.then((_) => sendConnect());
    _subscriptions.addAll([
      _socket.on.get(replicantPath(_name), onGetReplicant),
      _socket.on.get(dataPath(_name), onGetData),
      _socket.on.put(connectPath(_name), (req, res) => onConnect(req.data)),
      _socket.on.put(dataPath(_name), (req, res) => onData(req.data)),
      _socket.on.put(syncPath(_name), (req, res) => onSync(req.data)),
    ]);
    _socket.done.then((_) => cancel());
  }

  String get localId => _sync.id;
  String get remoteId => _replicant?.id;

  bool sentConnect = false;
  bool isConnected = false;
  bool isPeerConnected = false;
  bool isPeerConnecting = false;
  bool isSynced = false;
  bool isPeerSynced = false;
  bool isPeerSyncing = false;

  Future<void> onGetReplicant(WsRequest req, WsResponse res) async {
    res.send(data: await _sync.createReplicant());
  }

  Future<void> onGetData(WsRequest req, WsResponse res) async {
    res.send(data: _sync.repo.get().map((r) => r.toJsonString()).transform(utf8.encoder));
  }

  Future<void> sendConnect() async {
    sentConnect = true;
    if(!isPeerConnecting && !isPeerConnected) {
      isPeerConnecting = true;
      isPeerConnected = (await _socket.put(connectPath(_name), localId, retry: true)).isSuccess;
      isPeerConnecting = false;
    }
    await syncCheck();
  }

  Future<void> onConnect(WsData data) async {
    final rid = data.value as String;
    final replicant = await _sync._getReplicant(rid: rid);
    attach(replicant);
    isConnected = true;
    if(sentConnect) await syncCheck();
    else await sendConnect();
  }

  Future<void> syncCheck() async {
    if(isConnected && isPeerConnected) {
      await sendSync();
    }
  }

  Future<void> sendSync() async {
    if(isConnected && isPeerConnected && !isPeerSynced && !isPeerSyncing) {
      isPeerSyncing = true;
      final records = await _replicant.getSyncRecords(_sync.models);
      final data = await records.toList();
      // print('sendSync($_name: ${_sync.id}) $data');
      // final data = records.map((r) => r.toJsonString()).transform(utf8.encoder);
      isPeerSynced = (await _socket.put(syncPath(_name), data)).isSuccess;
      isPeerSyncing = false;
    }
    readyCheck();
  }

  Future<void> onSync(WsData data) async {
    isSynced = true;
    // final stream = data.stream.transform(utf8.decoder).map((s) => DataRecord.fromLine(s));
    // final records = await stream.toList();
    final records = (data.value as List).map((s) => DataRecord.fromLine(s)).toList();
    // print('onSync($_name: ${_sync.id}) $records');
    final event = DataEvent(remoteId, records);
    await onData(event);
    await sendSync();
  }

  void readyCheck() {
    if(isConnected && isPeerConnected && isSynced && isPeerSynced) {
      _ready.complete();
    }
  }

  /// new local records -> send them out via put(dataPath, event)
  Future<bool> sendData(data) async {
    final event = (data is DataEvent) ? data : (data is List<DataRecord>) ? DataEvent(localId, data) : null;
    print('sendData($_name: ${_sync.id}) $event');
    if(event != null && event.isNotEmpty) {
      return (await _socket.put(dataPath(_name), event)).isSuccess;
    }
    return true; // nothing to do
  }

  /// new remote records -> update local db and then notify other binders (with same event)
  Future<void> onData(data) async {
    final event = (data is DataEvent) ? data : (data is WsData) ? DataEvent.fromJson(data.value) : null;
    // print('onData($_name: ${_sync.id}) $event');
    if(event != null && event.isNotEmpty && event.visit(localId)) {
      _sync.models.loadAll(event.records);
      _sync.repo.putAll(event.records);
      // print('onDataBinders(${_sync.binders})');
      for(var binder in _sync.binders.values) {
        if(event.notVisitedBy(binder.remoteId)) {
          await binder.sendData(event);
        }
      }
    }
  }

  Future<void> get ready => _ready.future;
  Future<void> get finished => _finished.future;

  void attach(platform.Replicant replicant) {
    _replicant = replicant;
    _replicant._binder = this;
  }
  void detach() {
    _replicant?._binder = null;
    _replicant = null;
  }
  void cancel() {
    detach();
    for(var s in _subscriptions) {
      s.cancel();
    }
    _subscriptions.clear();
    if(!_finished.isCompleted) _finished.complete();
  }

  @override
    String toString() => '$runtimeType(lid: $localId, rid: $remoteId)';
}

class Replicant implements Connection {

  final Data db;
  final String id;
  final _executor = Executor();
  Replicant(this.db, this.id);

  Replicant open() => throw UnsupportedError('platform not supported');
  Future<void> flush() => _executor.flush();
  Future<void> close() => _executor.cancel();

  Stream<DataRecord> getSyncRecords(Models models) => throw UnsupportedError('platform not supported');

  Future<void> save() => throw UnsupportedError('platform not supported');
  Future<void> saveRecords(Iterable<DataRecord> records) => throw UnsupportedError('platform not supported');

  Binder _binder;
  bool get isConnected => _binder != null;
  bool get isNotConnected => !isConnected;

  /// new records in db, notify the socket or save relevant records for a future sync
  void putAll(Iterable<DataRecord> records) async {
    if(records.isNotEmpty) {
      if(isConnected) {
        _executor.add(() => _binder.sendData(records).then((_) => save()));
      } else {
        _executor.add(() => saveRecords(records.where((r) => r.isDelete)));
      }
    }
  }
}

class DataEvent extends Json {

  final Set<String> history;
  final List<DataRecord> records;

  DataEvent(String srcId, this.records) : history = {srcId};
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
