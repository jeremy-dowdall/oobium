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

const replicantPath = '/db/replicant';
const connectPath = '/db/connect';
const syncPath = '/db/sync';
const dataPath = '/db/data';

class Sync implements Connection {

  final Data db;
  final Models models;
  final Repo repo;
  Sync(this.db, this.repo, [this.models]);

  String id;
  final binders = <WebSocket, Binder>{};
  final replicants = <platform.Replicant>[];

  Future<Sync> open() => throw UnsupportedError('platform not supported');

  Future<void> close({bool cancel = false}) async {
    for(var replicant in replicants) {
      await replicant.close(cancel: cancel ?? false);
    }
    id = null;
    replicants.clear();
  }

  Future<void> save() => throw UnsupportedError('platform not supported');

  void put(Iterable<DataRecord> records) {
    repo.putAll(records);
    for(var replicant in replicants) {
      replicant.putAll(records);
    }
  }

  Future<void> bind(WebSocket socket) {
    if(binders.containsKey(socket)) {
      return Future.value();
    } else {
      final binder = Binder(this, socket);
      binders[socket] = binder;
      binder.finished.then((_) => binders.remove(socket));
      return binder.ready;
    }
  }

  Future<void> unbind(WebSocket socket) {
    final binder = binders.remove(socket);
    return (binder != null) ? binder.cancel() : Future.value();
  }

  Future<void> replicate(WebSocket socket) async {
    await _getReplicant(socket);
    await _getReplicantData(socket);
  }
  Future<void> _getReplicant(WebSocket socket) async {
    final result = await socket.get(replicantPath, retry: true);
    if(result.isSuccess) {
      final response = result.data.split(':');
      id = response[1]; // TODO assert this is null to begin with?
      await _addReplicant(response[0]);
    }
  }
  Future<void> _getReplicantData(WebSocket socket) async {
    final result = await socket.get(dataPath, retry: true);
    if(result.isSuccess) {
      if(result is WsStreamResult) {
        await repo.put(result.data.transform(utf8.decoder).map((s) => DataRecord.fromLine(s)));
      }
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
    await replicant.save();
    replicants.add(replicant);
    await save();
    return replicant;
  }
}

class Binder {

  final Sync _sync;
  final WebSocket _socket;
  final _ready = Completer();
  final _finished = Completer();
  final _subscriptions = <WsSubscription>[];
  platform.Replicant _replicant;
  Binder(this._sync, this._socket) {
    _socket.ready.then((_) => sendConnect());
    _subscriptions.addAll([
      _socket.on.get(replicantPath, onGetReplicant),
      _socket.on.get(dataPath, onGetData),
      _socket.on.put(connectPath, (req, res) => onConnect(req.data)),
      _socket.on.put(dataPath, (req, res) => onData(req.data)),
      _socket.on.put(syncPath, (req, res) async => onSync(req.data)),
    ]);
    _socket.done.then((_) => cancel());
  }

  String localId;
  String get remoteId => _replicant.id;

  bool isConnected = false;
  bool isPeerConnected = false;
  bool isSynced = false;
  bool isPeerSynced = false;

  Future<void> onGetReplicant(WsRequest req, WsResponse res) async {
    res.send(data: await _sync.createReplicant());
  }

  Future<void> onGetData(WsRequest req, WsResponse res) async {
    res.send(data: _sync.repo.get().map((r) => r.toJsonString()).transform(utf8.encoder));
  }

  Future<void> sendConnect() async {
    localId = _sync.id;
    if(localId != null && !isPeerConnected) {
      isPeerConnected = (await _socket.put(connectPath, localId, retry: true)).isSuccess;
    }
    await syncCheck();
  }

  Future<void> onConnect(WsData data) async {
    final rid = data.value as String;
    final replicant = _sync.replicants.firstWhere((r) => r.id == rid, orElse: () => null);
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
      final records = await _replicant.getSyncRecords(_sync.models);
      final data = await records.toList();
      // final data = records.map((r) => r.toJsonString()).transform(utf8.encoder);
      isPeerSynced = (await _socket.put(syncPath, data)).isSuccess;
    }
    readyCheck();
  }

  Future<void> onSync(WsData data) async {
    isSynced = true;
    // final stream = data.stream.transform(utf8.decoder).map((s) => DataRecord.fromLine(s));
    // final records = await stream.toList();
    final records = (data.value as List).map((s) => DataRecord.fromLine(s)).toList();
    final event = DataEvent(remoteId, records);
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
    final event = (data is DataEvent) ? data : (data is List<DataRecord>) ? DataEvent(localId, data) : null;
    if(event != null && event.isNotEmpty) {
      return (await _socket.put(dataPath, event)).isSuccess;
    }
    return true; // nothing to do
  }

  /// new remote records -> update local db and then notify other binders (with same event)
  Future<void> onData(data) async {
    final event = (data is DataEvent) ? data : (data is WsData) ? DataEvent.fromJson(data.value) : null;
    if(event != null && event.isNotEmpty && event.visit(localId)) {
      _sync.models.loadAll(event.records);
      _sync.repo.putAll(event.records);
      for(var binder in _sync.binders.values) {
        if(event.notVisitedBy(binder.remoteId)) {
          await binder.sendData(event);
        }
      }
    }
  }

  Future<void> get ready => _ready.future;
  Future<void> get finished => _finished.future;

  Future<void> attach(platform.Replicant replicant) async {
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

class Replicant implements Connection {

  final Data db;
  final String id;
  Replicant(this.db, this.id);

  Future<Replicant> open() => throw UnsupportedError('platform not supported');
  Future<void> close({bool cancel = false}) => stopTracking(cancel: cancel ?? false);

  Stream<DataRecord> getSyncRecords(Models models) => throw UnsupportedError('platform not supported');

  Future<void> save() => throw UnsupportedError('platform not supported');
  Future<void> saveRecords(Iterable<DataRecord> records) => throw UnsupportedError('platform not supported');

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

  Executor _executor;
  Future<void> startTracking() async {
    _executor = Executor();
  }
  Future<void> stopTracking({bool cancel = false}) async {
    await _executor?.close(cancel: cancel);
    _executor = null;
  }

  /// new records in db, notify the socket or save relevant records for a future sync
  void putAll(Iterable<DataRecord> records) async {
    if(records.isNotEmpty) {
      if(isConnected) {
        _binder.sendData(records).then((_) => save());
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
