import 'dart:async';

import 'package:oobium/src/datastore/data.dart';
import 'package:oobium/src/datastore/models.dart';
import 'package:oobium/src/datastore/repo.dart';
import 'package:oobium/src/datastore/sync.dart';
import 'package:oobium/src/json.dart';
import 'package:oobium/src/websocket.dart';
import 'package:xstring/xstring.dart';

export 'package:oobium/src/datastore/models.dart' show DataModel, DataModelEvent;

class UpgradeEvent {
  final int oldVersion;
  final int newVersion;
  final Stream<DataRecord> oldData;
  UpgradeEvent._(this.oldVersion, this.newVersion, this.oldData);
}

class DataStore {

  static Future<void> clean(String path) => Data(path).destroy();

  final String path;
  final List<Function(Map data)>? _builders;
  DataStore(this.path, [this._builders]) {
    assert(path.isNotBlank, 'datastore path cannot be blank');
  }

  int _version = 0;
  Models? _models;
  Data? _data;
  Repo? _repo;
  Sync? _sync;

  int get version => _version;

  int get size => _models?.length ?? 0;
  bool get isEmpty => size == 0;
  bool get isNotEmpty => !isEmpty;
  
  bool _open = false;
  bool get isOpen => _open;
  bool get isNotOpen => !isOpen;

  Future<DataStore> open({int version=1, Stream<DataRecord> Function(UpgradeEvent event)? onUpgrade}) async {
    if(isNotOpen) {
      _open = true;
      _version = version;
      _data = await Data(path).open(version: version, onUpgrade: (event) async {
        if(onUpgrade != null) {
          final oldRepo = (event.oldData != null) ? (await Repo(event.oldData!).open()) : null;
          final stream = onUpgrade(UpgradeEvent._(event.oldVersion, event.newVersion, oldRepo?.get() ?? Stream<DataRecord>.empty()));
          final newRepo = await Repo(event.newData).open();
          newRepo.put(stream);
          await newRepo.close();
          await oldRepo?.close();
        }
        return true;
      });
      _repo = await Repo(_data!).open();
      _models = await Models(_builders).load(_repo!.get());
      _sync = await Sync(_data!, _repo!, _models).open();
    }
    return this;
  }

  Future<void> flush() async {
    await _sync?.flush();
    await _repo?.flush();
  }

  Future<void> close() async {
    _open = false;
    await _sync?.flush();
    await _sync?.close();
    await _repo?.flush();
    await _repo?.close();
    await _data?.close();
    await _models?.close();
    _models = null;
    _data = null;
    _repo = null;
    _sync = null;
  }

  Future<void> destroy() async {
    _open = false;
    await _sync?.close();
    await _repo?.close();
    await _data?.destroy();
    await _models?.close();
    _models = null;
    _data = null;
    _repo = null;
    _sync = null;
  }

  Future<void> reset({WebSocket? socket}) async {
    await destroy();
    if(socket != null) {
      final data = await Data(path).open();
      final repo = await Repo(data).open();
      final sync = await Sync(data, repo).open();
      await sync.replicate(socket);
    }
    await open();
  }

  bool any(String? id) => _models?.any(id) == true;
  bool none(String? id) => _models?.none(id) == true;

  List<T?> batch<T extends DataModel>({Iterable<T>? put, Iterable<String?>? remove}) => _batch(put: put, remove: remove);

  T? get<T extends DataModel>(String? id, {T? Function()? orElse}) => _models!.get<T>(id, orElse: orElse);
  Iterable<T> getAll<T extends DataModel>() => _models!.getAll<T>();

  T put<T extends DataModel>(T model) => batch(put: [model])[0]!;
  List<T> putAll<T extends DataModel>(Iterable<T> models) => _batch(put: models).whereType<T>().toList();

  T? remove<T extends DataModel>(String? id) => batch(remove: [id])[0] as T?;
  List<T?> removeAll<T extends DataModel>(Iterable<String> ids) => batch(remove: ids);

  Stream<T?> stream<T extends DataModel>(String id) => _models!.stream<T>(id);
  Stream<DataModelEvent<T>> streamAll<T extends DataModel>({bool Function(T model)? where}) => _models!.streamAll<T>(where: where);

  bool get isBound => _sync!.isBound;
  bool get isNotBound => _sync!.isNotBound;

  Future<void> bind(WebSocket socket, {String? name, bool wait = true}) => _sync!.bind(socket, name: name, wait: wait);
  void unbind(WebSocket socket, {String? name}) => _sync?.unbind(socket, name: name);

  List<T?> _batch<T extends DataModel>({Iterable<T>? put, Iterable<String?>? remove}) {
    final batch = _models!.batch(put: put, remove: remove);

    if(batch.isNotEmpty) {
      _sync?.put(batch.records);
    }

    return batch.results;
  }
}

class DataRecord implements JsonString {

  final String id;
  final String? type;
  final int timestamp;
  final Map<String, dynamic>? _data;
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

  Map<String, dynamic> get data => {...?_data, 'id': id, 'timestamp': timestamp};

  bool get isDelete => (type == null);
  bool get isNotDelete => !isDelete;

  @override
  String toJsonString() => toString();

  @override
  toString() => isDelete ? '$id:$timestamp' : '$id:$timestamp:$type${Json.encode(_data)}';
}
