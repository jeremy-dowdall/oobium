import 'dart:async';

import 'package:objectid/objectid.dart';
import 'package:oobium/src/datastore.dart';
import 'package:oobium/src/json.dart';

class Models {
  Models([List<Function(Map data)>? builders]) {
    _builders['DataModel'] = (data) => DataModel.fromJson(data, data.keys.map((k) => '$k').toSet(), {}, false);
    if(builders != null) for(var builder in builders) {
      final type = builder.runtimeType.toString().split(' => ')[1];
      _builders[type] = builder;
    }
  }
  
  final _builders = <String, Function(Map data)>{};
  final _models = <String, DataModel>{};
  StreamController<Batch>? _controller;
  Stream<Batch> get _stream {
    _controller ??= StreamController<Batch>.broadcast(onCancel: () => _controller = null);
    return _controller!.stream;
  }

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

  void loadAll(Iterable<DataRecord> records) => batch(
    put: records.where((r) => r.isNotDelete).map((r) => _build(r)),
    remove: records.where((r) => r.isDelete).map((r) => r.id),
  );

  Future<void> close() {
    _models.clear();
    return _controller?.close() ?? Future.value();
  }

  bool any(String? id) => _models.containsKey(id);
  bool none(String? id) => !any(id);

  int get length => _models.length;
  bool get isEmpty => _models.isEmpty;
  bool get isNotEmpty => _models.isNotEmpty;

  T? get<T extends DataModel>(String? id, {T? Function()? orElse}) => (_models.containsKey(id)) ? (_models[id] as T) : orElse?.call();
  Iterable<T> getAll<T extends DataModel>() => (T == DataModel) ? (_models.values as Iterable<T>) : _models.values.whereType<T>();

  Stream<T?> stream<T extends DataModel>(String id) {
    return _stream
      .where((batch) => batch.updates.any((model) => (model is T) && (model.id == id)))
      .map((_) => (_models[id] is T) ? (_models[id] as T) : null);
  }

  Stream<DataModelEvent<T>> streamAll<T extends DataModel>({bool Function(T model)? where}) {
    return _stream
      .where((batch) => batch.updates.any((model) => (model is T) && ((where == null) || where(model))))
      .map((batch) => DataModelEvent<T>._(this, batch, where));
  }

  Batch<T> batch<T extends DataModel>({Iterable<T>? put, Iterable<String?>? remove}) {
    final batch = Batch<T>();

    if(put != null) for(var model in put) {
      if(model.isSameAs(_models[model.id])) {
        batch.results.add(model);
      } else {
        _models[model.id] = model;
        batch.results.add(model);
        batch.puts.add(model);
      }
      for(var member in model._fields.models) {
        if(member.isNotSameAs(_models[member.id])) {
          _models[member.id] = member;
          batch.puts.add(member);
        }
      }
    }

    if(remove != null) for(var id in remove) {
      final model = _models.remove(id);
      batch.results.add((model is T) ? model : null);
      if(model != null) {
        batch.removes.add(model);
      }
    }

    for(var model in batch.puts) {
      model._fields._context = this;
    }

    if(batch.isNotEmpty) {
      _controller?.add(batch);
    }

    return batch;
  }

  DataModel _build(DataRecord record) {
    final builder = _builders[record.type] ?? _builders['DataModel'];
    assert(builder != null, 'no builder registered for ${record.type}');
    final value = builder!(record.data);
    assert(value is DataModel, 'builder did not return a DataModel: $value');
    return (value as DataModel).._fields._context = this;
  }
}

class Batch<T extends DataModel> {
  final results = <T?>[];
  final puts = <DataModel>[];
  final removes = <DataModel>[];
  bool get isEmpty => puts.isEmpty && removes.isEmpty;
  bool get isNotEmpty => !isEmpty;
  Iterable<DataRecord> get records => [...puts.map((m) => DataRecord.fromModel(m)), ...removes.map((m) => DataRecord.delete(m.id))];
  Iterable<DataModel> get updates => [...puts, ...removes];
}

class DataModelEvent<T extends DataModel> {
  final Models _models;
  final Batch _batch;
  final bool Function(T model)? _where;
  DataModelEvent._(this._models, this._batch, this._where);

  Iterable<T> get all {
    if(_where == null) {
      return _models._models.values.whereType<T>();
    } else {
      return _models._models.values.whereType<T>().where(_where!);
    }
  }

  Iterable<T> get puts {
    if(_where == null) {
      return _batch.puts.whereType<T>();
    } else {
      return _batch.puts.whereType<T>().where(_where!);
    }
  }

  Iterable<T> get removes {
    if(_where == null) {
      return _batch.removes.whereType<T>();
    } else {
      return _batch.removes.whereType<T>().where(_where!);
    }
  }
}

class DataModel extends JsonModel implements DataId {
  final int timestamp;
  final DataFields _fields;

  DataModel([Map<String, dynamic>? fields]) :
        timestamp = DateTime.now().millisecondsSinceEpoch,
        _fields = DataFields(fields ?? {}),
        super(ObjectId().hexString);

  DataModel.copyNew(DataModel original, Map<String, dynamic>? fields) :
        timestamp = DateTime.now().millisecondsSinceEpoch,
        _fields = DataFields({...original._fields._map}..addAll((fields??{})..removeWhere((k,v) => v == null))),
        super(ObjectId().hexString);

  DataModel.copyWith(DataModel original, Map<String, dynamic>? fields) :
        timestamp = DateTime.now().millisecondsSinceEpoch,
        _fields = DataFields({...original._fields._map}..addAll((fields??{})..removeWhere((k,v) => v == null))),
        super(original.id);

  DataModel.fromJson(data, Set<String> fields, Set<String> modelFields, bool newId) :
        timestamp = Json.field<int?, int?>(data, 'timestamp') ?? DateTime.now().millisecondsSinceEpoch,
        _fields = DataFields({
          for(var k in fields.where((k) => k != 'id' && k != 'timestamp')) k: Json.field(data, k),
          for(var k in modelFields) k: DataId(Json.field(data, k))
        }),
        super(newId ? ObjectId().hexString : ObjectId.fromHexString(Json.field(data, 'id')).hexString);

  dynamic operator [](String key) => _fields[key];

  DateTime get createdAt => ObjectId.fromHexString(id).timestamp;
  DateTime get updatedAt => DateTime.fromMillisecondsSinceEpoch(timestamp);

  @override
  bool isSameAs(other) =>
      (runtimeType == other?.runtimeType) &&
      (id == other.id) && (timestamp == other.timestamp) &&
      _fields == other._fields;

  @override
  bool isNotSameAs(other) => !isSameAs(other);

  DataRecord toDataRecord() => DataRecord.fromModel(this);

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'timestamp': timestamp,
    for(var e in _fields._map.entries) e.key: Json.from(e.value)
  };

  @override
  String toString() => '${runtimeType.toString()}($id)';
}

class DataId implements JsonString {
  final String? id;
  DataId(this.id);
  @override
  String toJsonString() => '$id';
}

class DataFields {
  final Map<String, dynamic> _map;
  DataFields(this._map);

  late Models _context;

  Iterable<DataModel> get models => _map.values.whereType<DataModel>();

  operator [](String key) {
    final value = _map[key];
    if(value is DataModel) return value;
    if(value is DataId) return _context.get(value.id);
    return value;
  }

  bool operator ==(other) => (other is DataFields) && (_map.length == other._map.length) && _map.keys.every((k) => _(k) == other._(k));

  dynamic _(String key) {
    final obj = _map[key];
    if(obj is DataId) return obj.id;
    return obj;
  }
}
