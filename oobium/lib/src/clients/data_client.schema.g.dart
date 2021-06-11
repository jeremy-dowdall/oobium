import 'package:oobium_datastore/oobium_datastore.dart';

class DataClientData {
  final DataStore _ds;
  DataClientData(String path, {String? isolate})
      : _ds = DataStore('$path/data_client',
            isolate: isolate,
            builders: [(data) => Definition.fromJson(data)],
            indexes: []);
  Future<DataClientData> open(
          {int version = 1,
          Stream<DataRecord> Function(UpgradeEvent event)? onUpgrade}) =>
      _ds.open(version: version, onUpgrade: onUpgrade).then((_) => this);
  Future<void> flush() => _ds.flush();
  Future<void> close() => _ds.close();
  Future<void> destroy() => _ds.destroy();
  bool get isEmpty => _ds.isEmpty;
  bool get isNotEmpty => _ds.isNotEmpty;
  Definition? getDefinition(ObjectId? id, {Definition? Function()? orElse}) =>
      _ds.get<Definition>(id, orElse: orElse);
  Iterable<Definition> getDefinitions() => _ds.getAll<Definition>();
  Iterable<Definition> findDefinitions({String? name, String? access}) =>
      _ds.getAll<Definition>().where((m) =>
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
  DataClientModel.fromJson(
      data, Set<String> fields, Set<String> modelFields, bool newId)
      : super.fromJson(data, fields, modelFields, newId);
}

class Definition extends DataClientModel {
  ObjectId get id => this['_modelId'];
  String get name => this['name'];
  String? get access => this['access'];

  Definition({required String name, String? access})
      : super({'name': name, 'access': access});

  Definition.copyNew(Definition original, {String? name, String? access})
      : super.copyNew(original, {'name': name, 'access': access});

  Definition.copyWith(Definition original, {String? name, String? access})
      : super.copyWith(original, {'name': name, 'access': access});

  Definition.fromJson(data, {bool newId = false})
      : super.fromJson(data, {'name', 'access'}, {}, newId);

  Definition copyNew({String? name, String? access}) =>
      Definition.copyNew(this, name: name, access: access);

  Definition copyWith({String? name, String? access}) =>
      Definition.copyWith(this, name: name, access: access);
}
