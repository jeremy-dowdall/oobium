import 'package:oobium/oobium.dart';

class ModelGenTestData extends DataStore {
  ModelGenTestData(String path)
      : super('$path/model_gen_test',
            [(data) => User.fromJson(data), (data) => Message.fromJson(data)]);
}

class User extends DataModel {
  String? get name => this['name'];

  User({String? name}) : super({'name': name});

  User.copyNew(User original, {String? name})
      : super.copyNew(original, {'name': name});

  User.copyWith(User original, {String? name})
      : super.copyWith(original, {'name': name});

  User.fromJson(data, {bool newId = false})
      : super.fromJson(data, {'name'}, {}, newId);

  User copyNew({String? name}) => User.copyNew(this, name: name);

  User copyWith({String? name}) => User.copyWith(this, name: name);
}

class Message extends DataModel {
  User? get from => this['from'];
  User? get to => this['to'];
  String? get message => this['message'];

  Message({User? from, User? to, String? message})
      : super({'from': from, 'to': to, 'message': message});

  Message.copyNew(Message original, {User? from, User? to, String? message})
      : super.copyNew(original, {'from': from, 'to': to, 'message': message});

  Message.copyWith(Message original, {User? from, User? to, String? message})
      : super.copyWith(original, {'from': from, 'to': to, 'message': message});

  Message.fromJson(data, {bool newId = false})
      : super.fromJson(data, {'message'}, {'from', 'to'}, newId);

  Message copyNew({User? from, User? to, String? message}) =>
      Message.copyNew(this, from: from, to: to, message: message);

  Message copyWith({User? from, User? to, String? message}) =>
      Message.copyWith(this, from: from, to: to, message: message);
}
