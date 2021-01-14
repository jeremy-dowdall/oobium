import 'dart:async';

import 'package:objectid/objectid.dart';
import 'package:oobium/src/database.dart';
import 'package:oobium/src/json.dart';

class Models {

  Models([List<Function(Map data)> builders]) {
    _builders['DataModel'] = (data) => DataModel.fromJson(data, data.keys.toSet(), {});
    if(builders != null) for(var builder in builders) {
      final type = builder.runtimeType.toString().split(' => ')[1];
      _builders[type] = builder;
    }
  }
  
  final _builders = <String, Function(Map data)>{};
  final _models = <String, DataModel>{};
  StreamController<Iterable<DataModel>> _controller;

  Future<Models> load(Stream<DataRecord> records) async {
    await for(var record in records) {
      if(record.isDelete) {
        _models.remove(record.id);
      } else {
        _models[record.id] = _build(record);
      }
    }
    return this;
  }

  void loadAll(Iterable<DataRecord> records) {
    for(var record in records) {
      if(record.isDelete) {
        _models.remove(record.id);
      } else {
        _models[record.id] = _build(record);
      }
    }
  }

  Future<void> close() {
    _models.clear();
    return _controller?.close() ?? Future.value();
  }

  int get length => _models.length;

  T get<T extends DataModel>(String id, {T Function() orElse}) => (_models.containsKey(id)) ? (_models[id] as T) : orElse?.call();
  Iterable<T> getAll<T extends DataModel>() => (T == DataModel) ? _models.values : _models.values.whereType<T>();

  Stream<T> stream<T extends DataModel>(String id) {
    if(_controller == null) {
      _controller = StreamController<Iterable<DataModel>>.broadcast(onCancel: () => _controller = null);
    }
    return _controller.stream
      .where((updates) => updates.any((model) => (model.id == id)))
      .map((updates) => _models[id]);
  }

  Stream<Iterable<T>> streamAll<T extends DataModel>({bool Function(T model) where}) {
    if(_controller == null) {
      _controller = StreamController<Iterable<DataModel>>.broadcast(onCancel: () => _controller = null);
    }
    if(where == null) {
      return _controller.stream
        .where((updates) => updates.any((model) => model is T))
        .map((_) => _models.values.whereType<T>());
    } else {
      return _controller.stream
        .where((updates) => updates.any((model) => (model is T) && where(model)))
        .map((_) => _models.values.whereType<T>().where(where));
    }
  }

  Batch<T> batch<T extends DataModel>({Iterable<T> put, Iterable<String> remove}) {
    final batch = Batch<T>();

    if(put != null) for(var model in put) {
      if(model.isSameAs(_models[model.id])) {
        batch.results.add(model);
      } else {
        _models[model.id] = model;
        batch.results.add(model);
        batch.put.add(model);
      }
      for(var member in model._fields.models) {
        if(member.isNotSameAs(_models[member.id])) {
          _models[member.id] = member;
          batch.put.add(member);
        }
      }
    }
    if(remove != null) for(var id in remove) {
      final model = _models.remove(id);
      batch.results.add(model);
      if(model != null) {
        batch.remove.add(model);
      }
    }

    if(batch.isNotEmpty) {
      _controller?.add(batch.updates);
    }

    return batch;
  }

  DataModel _build(DataRecord record) {
    final builder = _builders[record.type] ?? _builders['DataModel'];
    assert(builder != null, 'no builder registered for ${record.type}');
    final value = builder(record.data);
    assert(value is DataModel, 'builder did not return a DataModel: $value');
    return (value as DataModel).._fields._context = this;
  }
}

class Batch<T extends DataModel> {
  final results = <T>[];
  final put = <DataModel>[];
  final remove = <DataModel>[];
  bool get isEmpty => put.isEmpty && remove.isEmpty;
  bool get isNotEmpty => !isEmpty;
  Iterable<DataRecord> get records => [...put.map((m) => DataRecord.fromModel(m)), ...remove.map((m) => DataRecord.delete(m.id))];
  Iterable<DataModel> get updates => [...put, ...remove];
}

class DataModel extends JsonModel implements DataId {

  final int timestamp;
  final DataFields _fields;

  DataModel([Map<String, dynamic> fields]) :
        timestamp = DateTime.now().millisecondsSinceEpoch,
        _fields = DataFields(fields ?? {}),
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
          for(var k in fields.where((k) => k != 'id' && k != 'timestamp')) k: Json.field(data, k),
          for(var k in modelFields) k: DataId(Json.field(data, k))
        }),
        super.fromJson(data);

  dynamic operator [](String key) => _fields[key];

  // DataModel copyNew();
  // DataModel copyWith();

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

  Models _context;

  Iterable<DataModel> get models => _map.values.whereType<DataModel>();

  operator [](String key) {
    final value = _map[key];
    if(value is DataModel) return value;
    if(value is DataId) return _context.get(value.id);
    return value;
  }

  bool operator ==(other) => (other is DataFields) && (_map.length == other._map.length) && _map.keys.every((k) => _(k) == other._(k));

  String _(String key) {
    final obj = _map[key];
    if(obj is DataId) return obj.id;
    return obj;
  }
}
