import 'dart:async';

import 'package:oobium/src/data/data.dart';
import 'package:oobium/src/data/models.dart';
import 'package:oobium/src/data/repo.dart';
import 'package:oobium/src/data/sync.dart';
import 'package:oobium/src/json.dart';
import 'package:oobium/src/websocket.dart';
import 'package:oobium/src/string.extensions.dart';

export 'package:oobium/src/data/models.dart' show DataModel;

class Database {

  static Future<void> clean(String path) => Data(path).destroy();

  final String path;
  final List<Function(Map data)> _builders;
  Database(this.path, [this._builders]) {
    assert(path.isNotBlank, 'database path cannot be blank');
  }

  Models _models;
  Data _data;
  Repo _repo;
  Sync _sync;

  int get size => _models?.length ?? 0;
  
  Future<Database> open() async {
    if(_data == null) {
      _data = await Data(path).create();
      _repo = await Repo(_data).open();
      _models = await Models(_builders).load(_repo.get());
      _sync = await Sync(_data, _repo, _models).open();
    }
    return this;
  }

  Future<void> flush() async {
    await _sync.flush();
    await _repo.flush();
  }

  Future<void> close() async {
    await _sync?.close();
    await _repo?.close();
    await _data?.close();
    await _models.close();
    _data = null;
    _repo = null;
    _sync = null;
  }

  Future<void> destroy() async {
    await _sync?.close(cancel: true);
    await _repo?.close(cancel: true);
    await _data?.destroy();
    await _models?.close();
    _models = null;
    _data = null;
    _repo = null;
    _sync = null;
  }

  Future<void> reset({WebSocket socket}) async {
    await destroy();
    if(socket != null) {
      final data = await Data(path).create();
      final repo = await Repo(data).open();
      final sync = await Sync(data, repo).open();
      await sync.replicate(socket);
    }
    await open();
  }

  List<T> batch<T extends DataModel>({Iterable<T> put, Iterable<String> remove}) => _batch(put: put, remove: remove);

  T get<T extends DataModel>(String id, {T Function() orElse}) => _models.get<T>(id, orElse: orElse);
  Iterable<T> getAll<T extends DataModel>() => _models.getAll<T>();

  T put<T extends DataModel>(T model) => batch(put: [model])[0];
  List<T> putAll<T extends DataModel>(Iterable<T> models) => batch(put: models);

  T remove<T extends DataModel>(String id) => batch(remove: [id])[0];
  List<T> removeAll<T extends DataModel>(Iterable<String> ids) => batch(remove: ids);

  Stream<T> stream<T extends DataModel>(String id) => _models.stream<T>(id);
  Stream<Iterable<T>> streamAll<T extends DataModel>({bool Function(T model) where}) => _models.streamAll<T>(where: where);

  Future<void> bind(WebSocket socket, {bool wait = true}) => open().then((_) => _sync.bind(socket, wait: wait));

  void unbind(WebSocket socket) => _sync?.unbind(socket);

  List<T> _batch<T extends DataModel>({Iterable<T> put, Iterable<String> remove}) {
    final batch = _models.batch(put: put, remove: remove);

    if(batch.isNotEmpty) {
      _sync?.put(batch.records);
    }

    return batch.results;
  }
}

class DataRecord implements JsonString {

  final String id;
  final String type;
  final int timestamp;
  final Map<String, dynamic> _data;
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

  Map<String, dynamic> get data => {..._data, 'id': id, 'timestamp': timestamp};

  bool get isDelete => (type == null);
  bool get isNotDelete => !isDelete;

  @override
  String toJsonString() => toString();

  @override
  toString() => isDelete ? '$id:$timestamp' : '$id:$timestamp:$type${Json.encode(_data)}';
}
