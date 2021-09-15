import 'package:oobium_datastore/oobium_datastore.dart';

class DataClientData {
  final DataStore _ds;
  DataClientData(String path, {DataStoreObserver? observer})
      : _ds = DataStore('$path/data_client',
            adapters: Adapters([
              Adapter<Definition>(
                  decode: (m) => Definition._(m),
                  encode: (k, v) => v,
                  fields: ['name', 'access'])
            ]),
            indexes: [],
            observer: observer);
  Future<DataClientData> open(
          {int version = 1,
          Stream<DataRecord> Function(UpgradeEvent event)? onUpgrade}) =>
      _ds.open(version: version, onUpgrade: onUpgrade).then((_) => this);
  Future<void> flush() => _ds.flush();
  Future<void> close() => _ds.close();
  Future<void> destroy() => _ds.destroy();
  Future<void> reset() => _ds.reset();
  bool get isEmpty => _ds.isEmpty;
  bool get isNotEmpty => _ds.isNotEmpty;
  bool get isOpen => _ds.isOpen;
  bool get isNotOpen => _ds.isNotOpen;
  Definition? getDefinition(ObjectId? id, {Definition? Function()? orElse}) =>
      _ds.get<Definition>(id, orElse: orElse);
  List<Definition> getDefinitions({bool Function(Definition model)? where}) =>
      _ds.getAll<Definition>(where: where);
  List<Definition> findDefinitions({String? name, String? access}) =>
      _ds.getAll<Definition>(
          where: (m) =>
              (name == null || name == m.name) &&
              (access == null || access == m.access));
  T put<T extends DataClientModel>(T model) => _ds.put<T>(model);
  List<T> putAll<T extends DataClientModel>(Iterable<T> models) =>
      _ds.putAll<T>(models);
  Definition putDefinition({required String name, String? access}) =>
      _ds.put(Definition(name: name, access: access));
  T remove<T extends DataClientModel>(T model) => _ds.remove<T>(model);
  List<T> removeAll<T extends DataClientModel>(Iterable<T> models) =>
      _ds.removeAll<T>(models);
  Stream<Definition?> streamDefinition(ObjectId id) =>
      _ds.stream<Definition>(id);
  Stream<DataModelEvent<Definition>> streamDefinitions(
          {bool Function(Definition model)? where}) =>
      _ds.streamAll<Definition>(where: where);
}

abstract class DataClientModel extends DataModel {
  DataClientModel([Map<String, dynamic>? fields]) : super(fields);
  DataClientModel.copyNew(
      DataClientModel original, Map<String, dynamic>? fields)
      : super.copyNew(original, fields);
  DataClientModel.copyWith(
      DataClientModel original, Map<String, dynamic>? fields)
      : super.copyWith(original, fields);
  DataClientModel.deleted(DataClientModel original) : super.deleted(original);
}

class Definition extends DataClientModel {
  ObjectId get id => this['_modelId'];
  String get name => this['name'];
  String? get access => this['access'];

  Definition({required String name, String? access})
      : super({'name': name, 'access': access});

  Definition._(map) : super(map);

  Definition._copyNew(Definition original,
      {required String name, String? access})
      : super.copyNew(original, {'name': name, 'access': access});

  Definition._copyWith(Definition original, {String? name, String? access})
      : super.copyWith(original, {'name': name, 'access': access});

  Definition._deleted(Definition original) : super.deleted(original);

  Definition copyNew({required String name, String? access}) =>
      Definition._copyNew(this, name: name, access: access);

  Definition copyWith({String? name, String? access}) =>
      Definition._copyWith(this, name: name, access: access);

  @override
  Definition deleted() => Definition._deleted(this);
}
