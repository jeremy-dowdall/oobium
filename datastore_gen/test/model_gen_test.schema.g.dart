import 'package:oobium_datastore/oobium_datastore.dart';

class ModelGenTestData {
  final DataStore _ds;
  ModelGenTestData(String path, {String? isolate})
      : _ds = DataStore('$path/model_gen_test',
            isolate: isolate,
            adapters: Adapters([
              Adapter<User>(
                  decode: (m) => User._(m),
                  encode: (k, v) => v,
                  fields: ['id', 'name']),
              Adapter<Message>(
                  decode: (m) {
                    if (m['from'] != null) {
                      m['from'] = DataId(m['from']);
                    }
                    if (m['to'] != null) {
                      m['to'] = DataId(m['to']);
                    }
                    return Message._(m);
                  },
                  encode: (k, v) => v,
                  fields: ['from', 'to', 'message'])
            ]),
            indexes: [DataIndex<User>(toKey: (m) => m.id)]);
  Future<ModelGenTestData> open(
          {int version = 1,
          Stream<DataRecord> Function(UpgradeEvent event)? onUpgrade}) =>
      _ds.open(version: version, onUpgrade: onUpgrade).then((_) => this);
  Future<void> flush() => _ds.flush();
  Future<void> close() => _ds.close();
  Future<void> destroy() => _ds.destroy();
  bool get isEmpty => _ds.isEmpty;
  bool get isNotEmpty => _ds.isNotEmpty;
  bool get isOpen => _ds.isOpen;
  bool get isNotOpen => _ds.isNotOpen;
  User? getUser(int? id, {User? Function()? orElse}) =>
      _ds.get<User>(id, orElse: orElse);
  Message? getMessage(ObjectId? id, {Message? Function()? orElse}) =>
      _ds.get<Message>(id, orElse: orElse);
  Iterable<User> getUsers() => _ds.getAll<User>();
  Iterable<Message> getMessages() => _ds.getAll<Message>();
  Iterable<User> findUsers({String? name}) =>
      _ds.getAll<User>().where((m) => (name == null || name == m.name));
  Iterable<Message> findMessages({User? from, User? to, String? message}) =>
      _ds.getAll<Message>().where((m) =>
          (from == null || from == m.from) &&
          (to == null || to == m.to) &&
          (message == null || message == m.message));
  T put<T extends ModelGenTestModel>(T model) => _ds.put<T>(model);
  List<T> putAll<T extends ModelGenTestModel>(Iterable<T> models) =>
      _ds.putAll<T>(models);
  User putUser({required int id, String? name}) => _ds
      .put(_ds.get<User>(id)?.copyWith(name: name) ?? User(id: id, name: name));
  Message putMessage({User? from, User? to, String? message}) =>
      _ds.put(Message(from: from, to: to, message: message));
  T remove<T extends ModelGenTestModel>(T model) => _ds.remove<T>(model);
  List<T> removeAll<T extends ModelGenTestModel>(Iterable<T> models) =>
      _ds.removeAll<T>(models);
  Stream<User?> streamUser(int id) => _ds.stream<User>(id);
  Stream<Message?> streamMessage(ObjectId id) => _ds.stream<Message>(id);
  Stream<DataModelEvent<User>> streamUsers(
          {bool Function(User model)? where}) =>
      _ds.streamAll<User>(where: where);
  Stream<DataModelEvent<Message>> streamMessages(
          {bool Function(Message model)? where}) =>
      _ds.streamAll<Message>(where: where);
}

abstract class ModelGenTestModel extends DataModel {
  ModelGenTestModel([Map<String, dynamic>? fields]) : super(fields);
  ModelGenTestModel.copyNew(
      ModelGenTestModel original, Map<String, dynamic>? fields)
      : super.copyNew(original, fields);
  ModelGenTestModel.copyWith(
      ModelGenTestModel original, Map<String, dynamic>? fields)
      : super.copyWith(original, fields);
  ModelGenTestModel.deleted(ModelGenTestModel original)
      : super.deleted(original);
}

class User extends ModelGenTestModel {
  int get id => this['id'];
  String? get name => this['name'];

  User({required int id, String? name}) : super({'id': id, 'name': name});

  User._(map) : super(map);

  User._copyNew(User original, {required int id, String? name})
      : super.copyNew(original, {'id': id, 'name': name});

  User._copyWith(User original, {String? name})
      : super.copyWith(original, {'name': name});

  User._deleted(User original) : super.deleted(original);

  User copyNew({required int id, String? name}) =>
      User._copyNew(this, id: id, name: name);

  User copyWith({String? name}) => User._copyWith(this, name: name);

  User deleted() => User._deleted(this);
}

class Message extends ModelGenTestModel {
  ObjectId get id => this['_modelId'];
  User? get from => this['from'];
  User? get to => this['to'];
  String? get message => this['message'];

  Message({User? from, User? to, String? message})
      : super({'from': from, 'to': to, 'message': message});

  Message._(map) : super(map);

  Message._copyNew(Message original, {User? from, User? to, String? message})
      : super.copyNew(original, {'from': from, 'to': to, 'message': message});

  Message._copyWith(Message original, {User? from, User? to, String? message})
      : super.copyWith(original, {'from': from, 'to': to, 'message': message});

  Message._deleted(Message original) : super.deleted(original);

  Message copyNew({User? from, User? to, String? message}) =>
      Message._copyNew(this, from: from, to: to, message: message);

  Message copyWith({User? from, User? to, String? message}) =>
      Message._copyWith(this, from: from, to: to, message: message);

  Message deleted() => Message._deleted(this);
}
