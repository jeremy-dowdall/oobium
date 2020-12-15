import 'package:objectid/objectid.dart';
import 'package:oobium_common/src/data/repo.dart';
import 'package:oobium_common/src/json.dart';
import 'package:oobium_common/src/websocket.dart';

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
  Repo _repo;

  String get id => null;
  int get size => _models.length;
  
  Future<void> open() async {
    await _openRepo();
  }
  Future<void> _openRepo() async {
    _repo = Repo(path);
    await _repo.open();
    await for(var record in _repo.read()) {
      if(record.isDelete) {
        _models.remove(record.id);
      } else {
        _models[record.id] = _build(record);
      }
    }
  }

  Future<void> close() async {
    await _repo.close();
    _repo = null;
  }

  Future<void> reset({Stream stream, WebSocket socket}) async {
    await destroy();
    if(socket != null) {
      // stream = (await socket.get(Binder.replicatePath, retry: true)).data as Stream<List<int>>;
    }
    if(stream != null) {
      final repo = Repo(path);
      await repo.writeStream(stream);
      // final sink = File('$path.init').openWrite(mode: FileMode.writeOnly);
      // await sink.addStream(stream);
      // await sink.flush();
      // await sink.close();
    }
    await open();
  }

  Future<void> destroy() async {
    await _repo?.destroy();
  }

  List<T> batch<T extends DataModel>({Iterable<T> put, Iterable<String> remove}) => _batch(put: put, remove: remove);

  T get<T extends DataModel>(String id, {T Function() orElse}) => (_models.containsKey(id)) ? (_models[id] as T) : orElse?.call();
  Iterable<T> getAll<T extends DataModel>() => (T == DataModel) ? _models.values : _models.values.whereType<T>();

  T put<T extends DataModel>(T model) => batch(put: [model])[0];
  List<T> putAll<T extends DataModel>(Iterable<T> models) => batch(put: models);

  T remove<T extends DataModel>(String id) => batch(remove: [id])[0];
  List<T> removeAll<T extends DataModel>(Iterable<String> ids) => batch(remove: ids);

  List<T> _batch<T extends DataModel>({Iterable<T> put, Iterable<String> remove}) {
    final results = <T>[];
    final records = <DataRecord>[];

    if(put != null) for(var model in put) {
      if(model.isSameAs(_models[model.id])) {
        results.add(model);
      } else {
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
      _commit(records);
      _notifyListeners(DataEvent(id, records));
    }

    return results;
  }

  DataModel _build(DataRecord record) {
    assert(_builders[record.type] != null, 'no builder registered for ${record.type}');
    final value = _builders[record.type](record.data);
    assert(value is DataModel, 'builder did not return a DataModel: $value');
    return (value as DataModel).._fields._db = this;
  }

  void _commit(List<DataRecord> records) {
    _repo?.write(records);
  }
  
  void _notifyListeners(DataEvent event) {
    // print('TODO _notifyListeners($event)');
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