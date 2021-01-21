import 'package:oobium/oobium.dart';

class DataClientData extends Database {
  DataClientData(String path)
      : super('$path/data_client', [(data) => Definition.fromJson(data)]);
}

class Definition extends DataModel {
  String get name => this['name'];
  String get access => this['access'];

  Definition({@required String name, String access})
      : super({'name': name, 'access': access});

  Definition.copyNew(Definition original, {String name, String access})
      : super.copyNew(original, {'name': name, 'access': access});

  Definition.copyWith(Definition original, {String name, String access})
      : super.copyWith(original, {'name': name, 'access': access});

  Definition.fromJson(data, {bool newId = false})
      : super.fromJson(data, {'name', 'access'}, {}, newId);

  Definition copyNew({String name, String access}) =>
      Definition.copyNew(this, name: name, access: access);

  Definition copyWith({String name, String access}) =>
      Definition.copyWith(this, name: name, access: access);
}
