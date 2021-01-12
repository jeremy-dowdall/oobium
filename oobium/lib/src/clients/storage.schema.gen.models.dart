import 'package:oobium/oobium.dart';

class StorageData extends Database {
  StorageData(String path)
      : super('$path/storage', [(data) => DbDefinition.fromJson(data)]);
}

class DbDefinition extends DataModel {
  String get name => this['name'];
  bool get shared => this['shared'];

  DbDefinition({String name, bool shared})
      : super({'name': name, 'shared': shared});

  DbDefinition.copyNew(DbDefinition original, {String name, bool shared})
      : super.copyNew(original, {'name': name, 'shared': shared});

  DbDefinition.copyWith(DbDefinition original, {String name, bool shared})
      : super.copyWith(original, {'name': name, 'shared': shared});

  DbDefinition.fromJson(data)
      : super.fromJson(
          data,
          {'name', 'shared'},
          {},
        );

  DbDefinition copyNew({String name, bool shared}) =>
      DbDefinition.copyNew(this, name: name, shared: shared);

  DbDefinition copyWith({String name, bool shared}) =>
      DbDefinition.copyWith(this, name: name, shared: shared);
}
