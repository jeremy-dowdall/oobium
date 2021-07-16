import 'dart:async';
import 'dart:convert';

import 'package:objectid/objectid.dart';
import 'package:oobium_datastore/src/datastore/data.dart';
import 'package:oobium_datastore/src/datastore/workers.dart';
import 'package:oobium_datastore/src/datastore/models.dart';
import 'package:xstring/xstring.dart';

class DataStore {

  static Future<void> clean(String path) => Data(path).destroy();

  final String path;
  final String? isolate;
  final List<Function(Map data)> _builders;
  final List<DataIndex> _indexes;
  final CompactionStrategy? _compactionStrategy;
  final bool _persist;
  DataStore(this.path, {
    this.isolate,
    List<Function(Map data)> builders = const[],
    List<DataIndex> indexes = const[],
    CompactionStrategy compactionStrategy = const DefaultCompactionStrategy()
  }) :
    assert(path.isNotBlank, 'datastore path cannot be blank'),
    _builders = builders,
    _indexes = indexes,
    _compactionStrategy = compactionStrategy,
    _persist = true
  ;
  DataStore.memory({
    List<Function(Map data)> builders = const[],
    List<DataIndex> indexes = const[],
  }) :
    path = '',
    isolate = null,
    _builders = builders,
    _indexes = indexes,
    _compactionStrategy = null,
    _persist = false
  ;

  Models? _models;
  DataWorker? _worker;

  int get version => _worker?.version ?? -1;

  int get size => _models?.modelCount ?? 0;
  bool get isEmpty => size == 0;
  bool get isNotEmpty => !isEmpty;
  
  bool _open = false;
  bool get isOpen => _open;
  bool get isNotOpen => !isOpen;

  Future<DataStore> open({int version=1, Stream<DataRecord> Function(UpgradeEvent event)? onUpgrade}) async {
    if(isNotOpen) {
      _open = true;
      if(_persist) {
        _worker = await DataWorker(path, isolate: isolate).open(version: version, onUpgrade: onUpgrade);
      }
      _models = await Models(_builders, _indexes).load(_worker?.getData() ?? Stream.empty());
    }
    return this;
  }

  Future<void> flush() async {
    await _worker?.flush();
  }

  Future<void> close() async {
    _open = false;
    await _worker?.close();
    await _models?.close();
    _worker = null;
    _models = null;
  }

  Future<void> destroy() async {
    _open = false;
    await _worker?.destroy();
    await _models?.close();
    _worker = null;
    _models = null;
  }

  Future<void> reset() async {
    await destroy();
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

  Stream<T?> stream<T extends DataModel>(Object id) => _models!.stream<T>(id);
  Stream<DataModelEvent<T>> streamAll<T extends DataModel>({bool Function(T model)? where}) => _models!.streamAll<T>(where: where);

  Future<void> compact() {
    final models = _models, worker = _worker;
    if(models != null && worker != null) {
      models.resetRecordCount();
      final records = models.getAll().map((m) => m.toDataRecord()).toList();
      return worker.putData(reset: records);
    } else {
      return Future.value();
    }
  }

  List<T> _batch<T extends DataModel>({Iterable<T>? put, Iterable<T>? remove}) {
    final start = DateTime.now();
    final models = _models!;
    final batch = models.batch(put: put, remove: remove);

    if(batch.isNotEmpty) {
      if(_shouldCompact()) {
        compact();
        print('batch w/compact executed in: ${DateTime.now().millisecondsSinceEpoch - start.millisecondsSinceEpoch} ms');
      } else {
        _worker?.putData(update: batch.records);
        print('batch w/out compact executed in: ${DateTime.now().millisecondsSinceEpoch - start.millisecondsSinceEpoch} ms');
      }
    }

    // print('batch executed in: ${DateTime.now().millisecondsSinceEpoch - start.millisecondsSinceEpoch} ms');
    return batch.results;
  }

  bool _shouldCompact() {
    final models = _models;
    if(models != null && models.modelCount > 0 && models.recordCount > 0) {
      return _compactionStrategy?.shouldCompact(models.modelCount, models.recordCount) ?? false;
    }
    return false;
  }
}

class DataRecord {

  final String modelId;
  final String updateId;
  final String type;
  final String? _data;
  DataRecord(this.modelId, this.updateId, this.type, [Map? data]) :
    _data = jsonEncode(data);
  DataRecord._(this.modelId, this.updateId, this.type, [this._data]);

  factory DataRecord.delete(DataModel model) => model.toDataRecord(delete: true);
  factory DataRecord.fromLine(String line) {
    // delete: <modelId>:<updateId>:<type>
    // full: <modelId>:<updateId>:<type>{jsonData}
    final modelId = line.substring(0, 24);
    final updateId = line.substring(25, 49);
    int ix = line.indexOf('{', 50);
    if(ix == -1) {
      return DataRecord._(modelId, updateId, line.substring(50));
    } else {
      final type = line.substring(50, ix);
      final data = line.substring(ix);
      return DataRecord._(modelId, updateId, type, data);
    }
  }
  factory DataRecord.fromModel(DataModel model) => model.toDataRecord();

  Map<String, dynamic> get data1 => {
    '_modelId': modelId,
    '_updateId': updateId,
    if(_data != null) ...jsonDecode(_data!)
  };

  bool get isDelete => (_data == null);
  bool get isNotDelete => !isDelete;

  String toJson() => toString();

  @override
  toString() => isDelete
    ? '$modelId:$updateId:$type'
    : '$modelId:$updateId:$type$_data';
}

class UpgradeEvent {
  final int oldVersion;
  final int newVersion;
  final Stream<DataRecord> oldData;
  UpgradeEvent(this.oldVersion, this.newVersion, this.oldData);
}

abstract class CompactionStrategy {

  const CompactionStrategy();

  bool shouldCompact(int modelCount, int recordCount);
}

class DefaultCompactionStrategy extends CompactionStrategy {

  const DefaultCompactionStrategy();

  @override
  bool shouldCompact(int modelCount, int recordCount) {
    if(recordCount <= 0) return false;
    final diff = recordCount - modelCount;
    final ratio = modelCount / recordCount;
    // print('compactCheck(diff: $diff, ratio: $ratio, models: ${modelCount}, records: ${recordCount})');
    return (diff > 4 && ratio < .75);
  }
}
