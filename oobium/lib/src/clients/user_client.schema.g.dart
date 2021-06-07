import 'package:objectid/objectid.dart';
import 'package:oobium/oobium.dart';

class UserClientData {
  final DataStore _ds;
  UserClientData(String path)
      : _ds = DataStore('$path/user_client', builders: [
          (data) => User.fromJson(data),
          (data) => Group.fromJson(data),
          (data) => Membership.fromJson(data)
        ], indexes: []);
  Future<UserClientData> open(
          {int version = 1,
          Stream<DataRecord> Function(UpgradeEvent event)? onUpgrade}) =>
      _ds.open(version: version, onUpgrade: onUpgrade).then((_) => this);
  Future<void> flush() => _ds.flush();
  Future<void> close() => _ds.close();
  Future<void> destroy() => _ds.destroy();
  bool get isEmpty => _ds.isEmpty;
  bool get isNotEmpty => _ds.isNotEmpty;
  User? getUser(ObjectId? id, {User? Function()? orElse}) =>
      _ds.get<User>(id, orElse: orElse);
  Group? getGroup(ObjectId? id, {Group? Function()? orElse}) =>
      _ds.get<Group>(id, orElse: orElse);
  Membership? getMembership(ObjectId? id, {Membership? Function()? orElse}) =>
      _ds.get<Membership>(id, orElse: orElse);
  Iterable<User> getUsers() => _ds.getAll<User>();
  Iterable<Group> getGroups() => _ds.getAll<Group>();
  Iterable<Membership> getMemberships() => _ds.getAll<Membership>();
  Iterable<User> findUsers({String? name, String? avatar}) =>
      _ds.getAll<User>().where((m) =>
          (name == null || name == m.name) &&
          (avatar == null || avatar == m.avatar));
  Iterable<Group> findGroups({String? name, User? owner}) =>
      _ds.getAll<Group>().where((m) =>
          (name == null || name == m.name) &&
          (owner == null || owner == m.owner));
  Iterable<Membership> findMemberships({User? user, Group? group}) =>
      _ds.getAll<Membership>().where((m) =>
          (user == null || user == m.user) &&
          (group == null || group == m.group));
  T put<T extends UserClientModel>(T model) => _ds.put<T>(model);
  User putUser({required String name, required String avatar}) =>
      _ds.put(User(name: name, avatar: avatar));
  Group putGroup({required String name, required User owner}) =>
      _ds.put(Group(name: name, owner: owner));
  Membership putMembership({required User user, required Group group}) =>
      _ds.put(Membership(user: user, group: group));
  T remove<T extends UserClientModel>(T model) => _ds.remove<T>(model);
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
  UserClientModel.fromJson(
      data, Set<String> fields, Set<String> modelFields, bool newId)
      : super.fromJson(data, fields, modelFields, newId);
}

class User extends UserClientModel {
  ObjectId get id => this['_modelId'];
  String get name => this['name'];
  String get avatar => this['avatar'];

  User({required String name, required String avatar})
      : super({'name': name, 'avatar': avatar});

  User.copyNew(User original, {String? name, String? avatar})
      : super.copyNew(original, {'name': name, 'avatar': avatar});

  User.copyWith(User original, {String? name, String? avatar})
      : super.copyWith(original, {'name': name, 'avatar': avatar});

  User.fromJson(data, {bool newId = false})
      : super.fromJson(data, {'name', 'avatar'}, {}, newId);

  User copyNew({String? name, String? avatar}) =>
      User.copyNew(this, name: name, avatar: avatar);

  User copyWith({String? name, String? avatar}) =>
      User.copyWith(this, name: name, avatar: avatar);
}

class Group extends UserClientModel {
  ObjectId get id => this['_modelId'];
  String get name => this['name'];
  User get owner => this['owner'];

  Group({required String name, required User owner})
      : super({'name': name, 'owner': owner});

  Group.copyNew(Group original, {String? name, User? owner})
      : super.copyNew(original, {'name': name, 'owner': owner});

  Group.copyWith(Group original, {String? name, User? owner})
      : super.copyWith(original, {'name': name, 'owner': owner});

  Group.fromJson(data, {bool newId = false})
      : super.fromJson(data, {'name'}, {'owner'}, newId);

  Group copyNew({String? name, User? owner}) =>
      Group.copyNew(this, name: name, owner: owner);

  Group copyWith({String? name, User? owner}) =>
      Group.copyWith(this, name: name, owner: owner);
}

class Membership extends UserClientModel {
  ObjectId get id => this['_modelId'];
  User get user => this['user'];
  Group get group => this['group'];

  Membership({required User user, required Group group})
      : super({'user': user, 'group': group});

  Membership.copyNew(Membership original, {User? user, Group? group})
      : super.copyNew(original, {'user': user, 'group': group});

  Membership.copyWith(Membership original, {User? user, Group? group})
      : super.copyWith(original, {'user': user, 'group': group});

  Membership.fromJson(data, {bool newId = false})
      : super.fromJson(data, {}, {'user', 'group'}, newId);

  Membership copyNew({User? user, Group? group}) =>
      Membership.copyNew(this, user: user, group: group);

  Membership copyWith({User? user, Group? group}) =>
      Membership.copyWith(this, user: user, group: group);
}
