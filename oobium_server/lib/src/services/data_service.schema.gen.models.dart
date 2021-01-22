import 'package:oobium/oobium.dart';

class DataServiceData extends Database {
  DataServiceData(String path)
      : super('$path/data_service', [(data) => Definition.fromJson(data)]);
}

class Definition extends DataModel {
  String get key => this['key'];
  String get name => this['name'];
  String get access => this['access'];

  Definition(
      {@required String key, @required String name, @required String access})
      : super({'key': key, 'name': name, 'access': access});

  Definition.copyNew(Definition original,
      {String key, String name, String access})
      : super.copyNew(original, {'key': key, 'name': name, 'access': access});

  Definition.copyWith(Definition original,
      {String key, String name, String access})
      : super.copyWith(original, {'key': key, 'name': name, 'access': access});

  Definition.fromJson(data, {bool newId = false})
      : super.fromJson(data, {'key', 'name', 'access'}, {}, newId);

  Definition copyNew({String key, String name, String access}) =>
      Definition.copyNew(this, key: key, name: name, access: access);

  Definition copyWith({String key, String name, String access}) =>
      Definition.copyWith(this, key: key, name: name, access: access);
}
