import 'package:oobium_datastore/oobium_datastore.dart';

class UserClientData {
  final DataStore _ds;
  UserClientData(String path, {DataStoreObserver? observer})
      : _ds = DataStore('$path/user_client',
            adapters: Adapters([
              Adapter<User>(
                  decode: (m) => User._(m),
                  encode: (k, v) => v,
                  fields: ['name', 'avatar']),
              Adapter<Group>(
                  decode: (m) {
                    m['owner'] = DataId(m['owner']);
                    return Group._(m);
                  },
                  encode: (k, v) => v,
                  fields: ['name', 'owner']),
              Adapter<Membership>(
                  decode: (m) {
                    m['user'] = DataId(m['user']);
                    m['group'] = DataId(m['group']);
                    return Membership._(m);
                  },
                  encode: (k, v) => v,
                  fields: ['user', 'group'])
            ]),
            indexes: [],
            observer: observer);
  Future<UserClientData> open(
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
  User? getUser(ObjectId? id, {User? Function()? orElse}) =>
      _ds.get<User>(id, orElse: orElse);
  Group? getGroup(ObjectId? id, {Group? Function()? orElse}) =>
      _ds.get<Group>(id, orElse: orElse);
  Membership? getMembership(ObjectId? id, {Membership? Function()? orElse}) =>
      _ds.get<Membership>(id, orElse: orElse);
  List<User> getUsers({bool Function(User model)? where}) =>
      _ds.getAll<User>(where: where);
  List<Group> getGroups({bool Function(Group model)? where}) =>
      _ds.getAll<Group>(where: where);
  List<Membership> getMemberships({bool Function(Membership model)? where}) =>
      _ds.getAll<Membership>(where: where);
  List<User> findUsers({String? name, String? avatar}) => _ds.getAll<User>(
      where: (m) =>
          (name == null || name == m.name) &&
          (avatar == null || avatar == m.avatar));
  List<Group> findGroups({String? name, User? owner}) => _ds.getAll<Group>(
      where: (m) =>
          (name == null || name == m.name) &&
          (owner == null || owner == m.owner));
  List<Membership> findMemberships({User? user, Group? group}) =>
      _ds.getAll<Membership>(
          where: (m) =>
              (user == null || user == m.user) &&
              (group == null || group == m.group));
  T put<T extends UserClientModel>(T model) => _ds.put<T>(model);
  List<T> putAll<T extends UserClientModel>(Iterable<T> models) =>
      _ds.putAll<T>(models);
  User putUser({required String name, String? avatar}) =>
      _ds.put(User(name: name, avatar: avatar));
  Group putGroup({required String name, required User owner}) =>
      _ds.put(Group(name: name, owner: owner));
  Membership putMembership({required User user, required Group group}) =>
      _ds.put(Membership(user: user, group: group));
  T remove<T extends UserClientModel>(T model) => _ds.remove<T>(model);
  List<T> removeAll<T extends UserClientModel>(Iterable<T> models) =>
      _ds.removeAll<T>(models);
  Stream<User?> streamUser(ObjectId id) => _ds.stream<User>(id);
  Stream<Group?> streamGroup(ObjectId id) => _ds.stream<Group>(id);
  Stream<Membership?> streamMembership(ObjectId id) =>
      _ds.stream<Membership>(id);
  Stream<DataModelEvent<User>> streamUsers(
          {bool Function(User model)? where}) =>
      _ds.streamAll<User>(where: where);
  Stream<DataModelEvent<Group>> streamGroups(
          {bool Function(Group model)? where}) =>
      _ds.streamAll<Group>(where: where);
  Stream<DataModelEvent<Membership>> streamMemberships(
          {bool Function(Membership model)? where}) =>
      _ds.streamAll<Membership>(where: where);
}

abstract class UserClientModel extends DataModel {
  UserClientModel([Map<String, dynamic>? fields]) : super(fields);
  UserClientModel.copyNew(
      UserClientModel original, Map<String, dynamic>? fields)
      : super.copyNew(original, fields);
  UserClientModel.copyWith(
      UserClientModel original, Map<String, dynamic>? fields)
      : super.copyWith(original, fields);
  UserClientModel.deleted(UserClientModel original) : super.deleted(original);
}

class User extends UserClientModel {
  ObjectId get id => this['_modelId'];
  String get name => this['name'];
  String? get avatar => this['avatar'];

  User({required String name, String? avatar})
      : super({'name': name, 'avatar': avatar});

  User._(map) : super(map);

  User._copyNew(User original, {required String name, String? avatar})
      : super.copyNew(original, {'name': name, 'avatar': avatar});

  User._copyWith(User original, {String? name, String? avatar})
      : super.copyWith(original, {'name': name, 'avatar': avatar});

  User._deleted(User original) : super.deleted(original);

  User copyNew({required String name, String? avatar}) =>
      User._copyNew(this, name: name, avatar: avatar);

  User copyWith({String? name, String? avatar}) =>
      User._copyWith(this, name: name, avatar: avatar);

  @override
  User deleted() => User._deleted(this);
}

class Group extends UserClientModel {
  ObjectId get id => this['_modelId'];
  String get name => this['name'];
  User get owner => this['owner'];

  Group({required String name, required User owner})
      : super({'name': name, 'owner': owner});

  Group._(map) : super(map);

  Group._copyNew(Group original, {required String name, required User owner})
      : super.copyNew(original, {'name': name, 'owner': owner});

  Group._copyWith(Group original, {String? name, User? owner})
      : super.copyWith(original, {'name': name, 'owner': owner});

  Group._deleted(Group original) : super.deleted(original);

  Group copyNew({required String name, required User owner}) =>
      Group._copyNew(this, name: name, owner: owner);

  Group copyWith({String? name, User? owner}) =>
      Group._copyWith(this, name: name, owner: owner);

  @override
  Group deleted() => Group._deleted(this);
}

class Membership extends UserClientModel {
  ObjectId get id => this['_modelId'];
  User get user => this['user'];
  Group get group => this['group'];

  Membership({required User user, required Group group})
      : super({'user': user, 'group': group});

  Membership._(map) : super(map);

  Membership._copyNew(Membership original,
      {required User user, required Group group})
      : super.copyNew(original, {'user': user, 'group': group});

  Membership._copyWith(Membership original, {User? user, Group? group})
      : super.copyWith(original, {'user': user, 'group': group});

  Membership._deleted(Membership original) : super.deleted(original);

  Membership copyNew({required User user, required Group group}) =>
      Membership._copyNew(this, user: user, group: group);

  Membership copyWith({User? user, Group? group}) =>
      Membership._copyWith(this, user: user, group: group);

  @override
  Membership deleted() => Membership._deleted(this);
}
