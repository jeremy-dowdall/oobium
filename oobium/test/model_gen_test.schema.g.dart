import 'package:oobium/oobium.dart';

class ModelGenTestData {
  final DataStore _ds;
  ModelGenTestData(String path)
      : _ds = DataStore('$path/model_gen_test',
            [(data) => User.fromJson(data), (data) => Message.fromJson(data)]);
  Future<ModelGenTestData> open(
          {int version = 1,
          Stream<DataRecord> Function(UpgradeEvent event)? onUpgrade}) =>
      _ds.open(version: version, onUpgrade: onUpgrade).then((_) => this);
  Future<void> close() => _ds.close();
  Future<void> destroy() => _ds.destroy();
  User? getUser(String? id, {User? Function()? orElse}) =>
      _ds.get<User>(id, orElse: orElse);
  Message? getMessage(String? id, {Message? Function()? orElse}) =>
      _ds.get<Message>(id, orElse: orElse);
  Iterable<User> getUsers() => _ds.getAll<User>();
  Iterable<Message> getMessages() => _ds.getAll<Message>();
  Iterable<User> findUsers({String? name}) =>
      _ds.getAll<User>().where((m) => (m.name == null || m.name == name));
  Iterable<Message> findMessages({User? from, User? to, String? message}) =>
      _ds.getAll<Message>().where((m) =>
          (m.from == null || m.from == from) &&
          (m.to == null || m.to == to) &&
          (m.message == null || m.message == message));
  T put<T extends ModelGenTestModel>(T model) => _ds.put<T>(model);
  User putUser({String? name}) => _ds.put(User(name: name));
  Message putMessage({User? from, User? to, String? message}) =>
      _ds.put(Message(from: from, to: to, message: message));
  T? remove<T extends ModelGenTestModel>(T? model) => _ds.remove<T>(model?.id);
  User? removeUser(String? id) => _ds.remove<User>(id);
  Message? removeMessage(String? id) => _ds.remove<Message>(id);
}

abstract class ModelGenTestModel extends DataModel {
  ModelGenTestModel([Map<String, dynamic>? fields]) : super(fields);
  ModelGenTestModel.copyNew(
      ModelGenTestModel original, Map<String, dynamic>? fields)
      : super.copyNew(original, fields);
  ModelGenTestModel.copyWith(
      ModelGenTestModel original, Map<String, dynamic>? fields)
      : super.copyWith(original, fields);
  ModelGenTestModel.fromJson(
      data, Set<String> fields, Set<String> modelFields, bool newId)
      : super.fromJson(data, fields, modelFields, newId);
}

class User extends ModelGenTestModel {
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

class Message extends ModelGenTestModel {
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
