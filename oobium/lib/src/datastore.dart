import 'dart:async';
import 'dart:convert';

import 'package:objectid/objectid.dart';
import 'package:oobium/src/datastore/data.dart';
import 'package:oobium/src/datastore/models.dart';
import 'package:oobium/src/datastore/repo.dart';
import 'package:oobium/src/datastore/sync.dart';
import 'package:oobium/src/websocket.dart';
import 'package:xstring/xstring.dart';

export 'package:oobium/src/datastore/models.dart' show DataModel, DataModelEvent, DataIndex;

class UpgradeEvent {
  final int oldVersion;
  final int newVersion;
  final Stream<DataRecord> oldData;
  UpgradeEvent._(this.oldVersion, this.newVersion, this.oldData);
}

class DataStore {

  static Future<void> clean(String path) => Data(path).destroy();

  final String path;
  final List<Function(Map data)> _builders;
  final List<DataIndex> _indexes;
  DataStore(this.path, [this._builders=const[], this._indexes=const[]]) {
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
      _models = await Models(_builders, _indexes).load(_repo!.get());
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

  bool any(ObjectId? id) => _models?.any(id) == true;
  bool none(ObjectId? id) => _models?.none(id) == true;

  List<T> batch<T extends DataModel>({Iterable<T>? put, Iterable<T>? remove}) => _batch(put: put, remove: remove);

  T? get<T extends DataModel>(Object? id, {T? Function()? orElse}) => _models!.get<T>(id, orElse: orElse);
  Iterable<T> getAll<T extends DataModel>() => _models!.getAll<T>();

  T put<T extends DataModel>(T model) => batch(put: [model])[0];
  List<T> putAll<T extends DataModel>(Iterable<T> models) => _batch(put: models).whereType<T>().toList();

  T remove<T extends DataModel>(T model) => batch(remove: [model])[0];
  List<T> removeAll<T extends DataModel>(Iterable<T> models) => batch(remove: models);

  Stream<T?> stream<T extends DataModel>(ObjectId id) => _models!.stream<T>(id);
  Stream<DataModelEvent<T>> streamAll<T extends DataModel>({bool Function(T model)? where}) => _models!.streamAll<T>(where: where);

  bool get isBound => _sync!.isBound;
  bool get isNotBound => _sync!.isNotBound;

  Future<void> bind(WebSocket socket, {String? name, bool wait = true}) => _sync!.bind(socket, name: name, wait: wait);
  void unbind(WebSocket socket, {String? name}) => _sync?.unbind(socket, name: name);

  List<T> _batch<T extends DataModel>({Iterable<T>? put, Iterable<T>? remove}) {
    final batch = _models!.batch(put: put, remove: remove);

    if(batch.isNotEmpty) {
      _sync?.put(batch.records);
    }

    return batch.results;
  }
}

class DataRecord {

  final String modelId;
  final String updateId;
  final String type;
  final Map<String, dynamic>? _data;
  DataRecord(this.modelId, this.updateId, this.type, [this._data]);

  factory DataRecord.delete(DataModel model) => model.toDataRecord(delete: true);
  factory DataRecord.fromLine(String line) {
    // delete: <modelId>:<updateId>:<type>
    // full: <modelId>:<updateId>:<type>{jsonData}
    final modelId = line.substring(0, 24);
    final updateId = line.substring(25, 49);
    int ix = line.indexOf('{', 50);
    if(ix == -1) {
      return DataRecord(modelId, updateId, line.substring(50));
    } else {
      final type = line.substring(50, ix);
      final data = jsonDecode(line.substring(ix));
      return DataRecord(modelId, updateId, type, data);
    }
  }
  factory DataRecord.fromModel(DataModel model) => model.toDataRecord();

  Map<String, dynamic> get data => {...?_data, '_modelId': modelId, '_updateId': updateId};

  bool get isDelete => (_data == null);
  bool get isNotDelete => !isDelete;

  String toJson() => toString();

  @override
  toString() => isDelete
    ? '$modelId:$updateId:$type'
    : '$modelId:$updateId:$type${jsonEncode(_data)}';
}
