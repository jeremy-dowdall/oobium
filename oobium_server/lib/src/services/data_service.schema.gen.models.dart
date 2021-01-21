import 'package:oobium/oobium.dart';

class DataServiceData extends Database {
  DataServiceData(String path)
      : super(
            '$path/data_service', [(data) => ClientDefinition.fromJson(data)]);
}

class ClientDefinition extends DataModel {
  String get key => this['key'];
  String get name => this['name'];
  String get access => this['access'];

  ClientDefinition(
      {@required String key, @required String name, @required String access})
      : super({'key': key, 'name': name, 'access': access});

  ClientDefinition.copyNew(ClientDefinition original,
      {String key, String name, String access})
      : super.copyNew(original, {'key': key, 'name': name, 'access': access});

  ClientDefinition.copyWith(ClientDefinition original,
      {String key, String name, String access})
      : super.copyWith(original, {'key': key, 'name': name, 'access': access});

  ClientDefinition.fromJson(data, {bool newId = false})
      : super.fromJson(data, {'key', 'name', 'access'}, {}, newId);

  ClientDefinition copyNew({String key, String name, String access}) =>
      ClientDefinition.copyNew(this, key: key, name: name, access: access);

  ClientDefinition copyWith({String key, String name, String access}) =>
      ClientDefinition.copyWith(this, key: key, name: name, access: access);
}
