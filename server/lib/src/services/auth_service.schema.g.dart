import 'package:objectid/objectid.dart';
import 'package:oobium/oobium.dart';

class AuthServiceData {
  final DataStore _ds;
  AuthServiceData(String path)
      : _ds = DataStore('$path/auth_service', [
          (data) => User.fromJson(data),
          (data) => Token.fromJson(data),
          (data) => Link.fromJson(data),
          (data) => Group.fromJson(data),
          (data) => Membership.fromJson(data)
        ], []);
  Future<AuthServiceData> open(
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
  Token? getToken(ObjectId? id, {Token? Function()? orElse}) =>
      _ds.get<Token>(id, orElse: orElse);
  Link? getLink(ObjectId? id, {Link? Function()? orElse}) =>
      _ds.get<Link>(id, orElse: orElse);
  Group? getGroup(ObjectId? id, {Group? Function()? orElse}) =>
      _ds.get<Group>(id, orElse: orElse);
  Membership? getMembership(ObjectId? id, {Membership? Function()? orElse}) =>
      _ds.get<Membership>(id, orElse: orElse);
  Iterable<User> getUsers() => _ds.getAll<User>();
  Iterable<Token> getTokens() => _ds.getAll<Token>();
  Iterable<Link> getLinks() => _ds.getAll<Link>();
  Iterable<Group> getGroups() => _ds.getAll<Group>();
  Iterable<Membership> getMemberships() => _ds.getAll<Membership>();
  Iterable<User> findUsers(
          {String? name, String? avatar, Token? token, User? referredBy}) =>
      _ds.getAll<User>().where((m) =>
          (name == null || name == m.name) &&
          (avatar == null || avatar == m.avatar) &&
          (token == null || token == m.token) &&
          (referredBy == null || referredBy == m.referredBy));
  Iterable<Token> findTokens({User? user}) =>
      _ds.getAll<Token>().where((m) => (user == null || user == m.user));
  Iterable<Link> findLinks(
          {User? user,
          String? type,
          String? code,
          Map<String, String>? data}) =>
      _ds.getAll<Link>().where((m) =>
          (user == null || user == m.user) &&
          (type == null || type == m.type) &&
          (code == null || code == m.code) &&
          (data == null || data == m.data));
  Iterable<Group> findGroups({String? name, User? owner}) =>
      _ds.getAll<Group>().where((m) =>
          (name == null || name == m.name) &&
          (owner == null || owner == m.owner));
  Iterable<Membership> findMemberships(
          {User? user, Group? group, User? invitedBy}) =>
      _ds.getAll<Membership>().where((m) =>
          (user == null || user == m.user) &&
          (group == null || group == m.group) &&
          (invitedBy == null || invitedBy == m.invitedBy));
  T put<T extends AuthServiceModel>(T model) => _ds.put<T>(model);
  User putUser(
          {required String name,
          String? avatar,
          Token? token,
          User? referredBy}) =>
      _ds.put(User(
          name: name, avatar: avatar, token: token, referredBy: referredBy));
  Token putToken({required User user}) => _ds.put(Token(user: user));
  Link putLink(
          {required User user,
          required String type,
          required String code,
          Map<String, String>? data}) =>
      _ds.put(Link(user: user, type: type, code: code, data: data));
  Group putGroup({required String name, required User owner}) =>
      _ds.put(Group(name: name, owner: owner));
  Membership putMembership(
          {required User user,
          required Group group,
          required User invitedBy}) =>
      _ds.put(Membership(user: user, group: group, invitedBy: invitedBy));
  T remove<T extends AuthServiceModel>(T model) => _ds.remove<T>(model);
  Stream<User?> streamUser(ObjectId id) => _ds.stream<User>(id);
  Stream<Token?> streamToken(ObjectId id) => _ds.stream<Token>(id);
  Stream<Link?> streamLink(ObjectId id) => _ds.stream<Link>(id);
  Stream<Group?> streamGroup(ObjectId id) => _ds.stream<Group>(id);
  Stream<Membership?> streamMembership(ObjectId id) =>
      _ds.stream<Membership>(id);
  Stream<DataModelEvent<User>> streamUsers(
          {bool Function(User model)? where}) =>
      _ds.streamAll<User>(where: where);
  Stream<DataModelEvent<Token>> streamTokens(
          {bool Function(Token model)? where}) =>
      _ds.streamAll<Token>(where: where);
  Stream<DataModelEvent<Link>> streamLinks(
          {bool Function(Link model)? where}) =>
      _ds.streamAll<Link>(where: where);
  Stream<DataModelEvent<Group>> streamGroups(
          {bool Function(Group model)? where}) =>
      _ds.streamAll<Group>(where: where);
  Stream<DataModelEvent<Membership>> streamMemberships(
          {bool Function(Membership model)? where}) =>
      _ds.streamAll<Membership>(where: where);
}

abstract class AuthServiceModel extends DataModel {
  AuthServiceModel([Map<String, dynamic>? fields]) : super(fields);
  AuthServiceModel.copyNew(
      AuthServiceModel original, Map<String, dynamic>? fields)
      : super.copyNew(original, fields);
  AuthServiceModel.copyWith(
      AuthServiceModel original, Map<String, dynamic>? fields)
      : super.copyWith(original, fields);
  AuthServiceModel.fromJson(
      data, Set<String> fields, Set<String> modelFields, bool newId)
      : super.fromJson(data, fields, modelFields, newId);
}

class User extends AuthServiceModel {
  ObjectId get id => this['_modelId'];
  String get name => this['name'];
  String? get avatar => this['avatar'];
  Token? get token => this['token'];
  User? get referredBy => this['referredBy'];

  User({required String name, String? avatar, Token? token, User? referredBy})
      : super({
          'name': name,
          'avatar': avatar,
          'token': token,
          'referredBy': referredBy
        });

  User.copyNew(User original,
      {String? name, String? avatar, Token? token, User? referredBy})
      : super.copyNew(original, {
          'name': name,
          'avatar': avatar,
          'token': token,
          'referredBy': referredBy
        });

  User.copyWith(User original,
      {String? name, String? avatar, Token? token, User? referredBy})
      : super.copyWith(original, {
          'name': name,
          'avatar': avatar,
          'token': token,
          'referredBy': referredBy
        });

  User.fromJson(data, {bool newId = false})
      : super.fromJson(
            data, {'name', 'avatar'}, {'token', 'referredBy'}, newId);

  User copyNew(
          {String? name, String? avatar, Token? token, User? referredBy}) =>
      User.copyNew(this,
          name: name, avatar: avatar, token: token, referredBy: referredBy);

  User copyWith(
          {String? name, String? avatar, Token? token, User? referredBy}) =>
      User.copyWith(this,
          name: name, avatar: avatar, token: token, referredBy: referredBy);
}

class Token extends AuthServiceModel {
  ObjectId get id => this['_modelId'];
  User get user => this['user'];

  Token({required User user}) : super({'user': user});

  Token.copyNew(Token original, {User? user})
      : super.copyNew(original, {'user': user});

  Token.copyWith(Token original, {User? user})
      : super.copyWith(original, {'user': user});

  Token.fromJson(data, {bool newId = false})
      : super.fromJson(data, {}, {'user'}, newId);

  Token copyNew({User? user}) => Token.copyNew(this, user: user);

  Token copyWith({User? user}) => Token.copyWith(this, user: user);
}

class Link extends AuthServiceModel {
  ObjectId get id => this['_modelId'];
  User get user => this['user'];
  String get type => this['type'];
  String get code => this['code'];
  Map<String, String>? get data => this['data'];

  Link(
      {required User user,
      required String type,
      required String code,
      Map<String, String>? data})
      : super({'user': user, 'type': type, 'code': code, 'data': data});

  Link.copyNew(Link original,
      {User? user, String? type, String? code, Map<String, String>? data})
      : super.copyNew(
            original, {'user': user, 'type': type, 'code': code, 'data': data});

  Link.copyWith(Link original,
      {User? user, String? type, String? code, Map<String, String>? data})
      : super.copyWith(
            original, {'user': user, 'type': type, 'code': code, 'data': data});

  Link.fromJson(data, {bool newId = false})
      : super.fromJson(data, {'type', 'code', 'data'}, {'user'}, newId);

  Link copyNew(
          {User? user,
          String? type,
          String? code,
          Map<String, String>? data}) =>
      Link.copyNew(this, user: user, type: type, code: code, data: data);

  Link copyWith(
          {User? user,
          String? type,
          String? code,
          Map<String, String>? data}) =>
      Link.copyWith(this, user: user, type: type, code: code, data: data);
}

class Group extends AuthServiceModel {
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

class Membership extends AuthServiceModel {
  ObjectId get id => this['_modelId'];
  User get user => this['user'];
  Group get group => this['group'];
  User get invitedBy => this['invitedBy'];

  Membership(
      {required User user, required Group group, required User invitedBy})
      : super({'user': user, 'group': group, 'invitedBy': invitedBy});

  Membership.copyNew(Membership original,
      {User? user, Group? group, User? invitedBy})
      : super.copyNew(
            original, {'user': user, 'group': group, 'invitedBy': invitedBy});

  Membership.copyWith(Membership original,
      {User? user, Group? group, User? invitedBy})
      : super.copyWith(
            original, {'user': user, 'group': group, 'invitedBy': invitedBy});

  Membership.fromJson(data, {bool newId = false})
      : super.fromJson(data, {}, {'user', 'group', 'invitedBy'}, newId);

  Membership copyNew({User? user, Group? group, User? invitedBy}) =>
      Membership.copyNew(this, user: user, group: group, invitedBy: invitedBy);

  Membership copyWith({User? user, Group? group, User? invitedBy}) =>
      Membership.copyWith(this, user: user, group: group, invitedBy: invitedBy);
}
