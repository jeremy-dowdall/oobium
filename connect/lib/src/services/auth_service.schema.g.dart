import 'package:oobium_datastore/oobium_datastore.dart';

class AuthServiceData {
  final DataStore _ds;
  AuthServiceData(String path, {String? isolate})
      : _ds = DataStore('$path/auth_service', isolate: isolate, builders: [
          (data) => AuthUser.fromJson(data),
          (data) => AuthToken.fromJson(data),
          (data) => AuthLink.fromJson(data),
          (data) => AuthGroup.fromJson(data),
          (data) => AuthMembership.fromJson(data)
        ], indexes: []);
  Future<AuthServiceData> open(
          {int version = 1,
          Stream<DataRecord> Function(UpgradeEvent event)? onUpgrade}) =>
      _ds.open(version: version, onUpgrade: onUpgrade).then((_) => this);
  Future<void> flush() => _ds.flush();
  Future<void> close() => _ds.close();
  Future<void> destroy() => _ds.destroy();
  bool get isEmpty => _ds.isEmpty;
  bool get isNotEmpty => _ds.isNotEmpty;
  AuthUser? getAuthUser(ObjectId? id, {AuthUser? Function()? orElse}) =>
      _ds.get<AuthUser>(id, orElse: orElse);
  AuthToken? getAuthToken(ObjectId? id, {AuthToken? Function()? orElse}) =>
      _ds.get<AuthToken>(id, orElse: orElse);
  AuthLink? getAuthLink(ObjectId? id, {AuthLink? Function()? orElse}) =>
      _ds.get<AuthLink>(id, orElse: orElse);
  AuthGroup? getAuthGroup(ObjectId? id, {AuthGroup? Function()? orElse}) =>
      _ds.get<AuthGroup>(id, orElse: orElse);
  AuthMembership? getAuthMembership(ObjectId? id,
          {AuthMembership? Function()? orElse}) =>
      _ds.get<AuthMembership>(id, orElse: orElse);
  Iterable<AuthUser> getAuthUsers() => _ds.getAll<AuthUser>();
  Iterable<AuthToken> getAuthTokens() => _ds.getAll<AuthToken>();
  Iterable<AuthLink> getAuthLinks() => _ds.getAll<AuthLink>();
  Iterable<AuthGroup> getAuthGroups() => _ds.getAll<AuthGroup>();
  Iterable<AuthMembership> getAuthMemberships() => _ds.getAll<AuthMembership>();
  Iterable<AuthUser> findAuthUsers(
          {String? name,
          String? avatar,
          AuthToken? token,
          AuthUser? referredBy}) =>
      _ds.getAll<AuthUser>().where((m) =>
          (name == null || name == m.name) &&
          (avatar == null || avatar == m.avatar) &&
          (token == null || token == m.token) &&
          (referredBy == null || referredBy == m.referredBy));
  Iterable<AuthToken> findAuthTokens({AuthUser? user}) =>
      _ds.getAll<AuthToken>().where((m) => (user == null || user == m.user));
  Iterable<AuthLink> findAuthLinks(
          {AuthUser? user,
          String? type,
          String? code,
          Map<String, String>? data}) =>
      _ds.getAll<AuthLink>().where((m) =>
          (user == null || user == m.user) &&
          (type == null || type == m.type) &&
          (code == null || code == m.code) &&
          (data == null || data == m.data));
  Iterable<AuthGroup> findAuthGroups({String? name, AuthUser? owner}) =>
      _ds.getAll<AuthGroup>().where((m) =>
          (name == null || name == m.name) &&
          (owner == null || owner == m.owner));
  Iterable<AuthMembership> findAuthMemberships(
          {AuthUser? user, AuthGroup? group, AuthUser? invitedBy}) =>
      _ds.getAll<AuthMembership>().where((m) =>
          (user == null || user == m.user) &&
          (group == null || group == m.group) &&
          (invitedBy == null || invitedBy == m.invitedBy));
  T put<T extends AuthServiceModel>(T model) => _ds.put<T>(model);
  List<T> putAll<T extends AuthServiceModel>(Iterable<T> models) =>
      _ds.putAll<T>(models);
  AuthUser putAuthUser(
          {required String name,
          String? avatar,
          AuthToken? token,
          AuthUser? referredBy}) =>
      _ds.put(AuthUser(
          name: name, avatar: avatar, token: token, referredBy: referredBy));
  AuthToken putAuthToken({required AuthUser user}) =>
      _ds.put(AuthToken(user: user));
  AuthLink putAuthLink(
          {required AuthUser user,
          required String type,
          required String code,
          Map<String, String> data = const {}}) =>
      _ds.put(AuthLink(user: user, type: type, code: code, data: data));
  AuthGroup putAuthGroup({required String name, required AuthUser owner}) =>
      _ds.put(AuthGroup(name: name, owner: owner));
  AuthMembership putAuthMembership(
          {required AuthUser user,
          required AuthGroup group,
          required AuthUser invitedBy}) =>
      _ds.put(AuthMembership(user: user, group: group, invitedBy: invitedBy));
  T remove<T extends AuthServiceModel>(T model) => _ds.remove<T>(model);
  List<T> removeAll<T extends AuthServiceModel>(Iterable<T> models) =>
      _ds.removeAll<T>(models);
  Stream<AuthUser?> streamAuthUser(ObjectId id) => _ds.stream<AuthUser>(id);
  Stream<AuthToken?> streamAuthToken(ObjectId id) => _ds.stream<AuthToken>(id);
  Stream<AuthLink?> streamAuthLink(ObjectId id) => _ds.stream<AuthLink>(id);
  Stream<AuthGroup?> streamAuthGroup(ObjectId id) => _ds.stream<AuthGroup>(id);
  Stream<AuthMembership?> streamAuthMembership(ObjectId id) =>
      _ds.stream<AuthMembership>(id);
  Stream<DataModelEvent<AuthUser>> streamAuthUsers(
          {bool Function(AuthUser model)? where}) =>
      _ds.streamAll<AuthUser>(where: where);
  Stream<DataModelEvent<AuthToken>> streamAuthTokens(
          {bool Function(AuthToken model)? where}) =>
      _ds.streamAll<AuthToken>(where: where);
  Stream<DataModelEvent<AuthLink>> streamAuthLinks(
          {bool Function(AuthLink model)? where}) =>
      _ds.streamAll<AuthLink>(where: where);
  Stream<DataModelEvent<AuthGroup>> streamAuthGroups(
          {bool Function(AuthGroup model)? where}) =>
      _ds.streamAll<AuthGroup>(where: where);
  Stream<DataModelEvent<AuthMembership>> streamAuthMemberships(
          {bool Function(AuthMembership model)? where}) =>
      _ds.streamAll<AuthMembership>(where: where);
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

class AuthUser extends AuthServiceModel {
  ObjectId get id => this['_modelId'];
  String get name => this['name'];
  String? get avatar => this['avatar'];
  AuthToken? get token => this['token'];
  AuthUser? get referredBy => this['referredBy'];

  AuthUser(
      {required String name,
      String? avatar,
      AuthToken? token,
      AuthUser? referredBy})
      : super({
          'name': name,
          'avatar': avatar,
          'token': token,
          'referredBy': referredBy
        });

  AuthUser.copyNew(AuthUser original,
      {String? name, String? avatar, AuthToken? token, AuthUser? referredBy})
      : super.copyNew(original, {
          'name': name,
          'avatar': avatar,
          'token': token,
          'referredBy': referredBy
        });

  AuthUser.copyWith(AuthUser original,
      {String? name, String? avatar, AuthToken? token, AuthUser? referredBy})
      : super.copyWith(original, {
          'name': name,
          'avatar': avatar,
          'token': token,
          'referredBy': referredBy
        });

  AuthUser.fromJson(data, {bool newId = false})
      : super.fromJson(
            data, {'name', 'avatar'}, {'token', 'referredBy'}, newId);

  AuthUser copyNew(
          {String? name,
          String? avatar,
          AuthToken? token,
          AuthUser? referredBy}) =>
      AuthUser.copyNew(this,
          name: name, avatar: avatar, token: token, referredBy: referredBy);

  AuthUser copyWith(
          {String? name,
          String? avatar,
          AuthToken? token,
          AuthUser? referredBy}) =>
      AuthUser.copyWith(this,
          name: name, avatar: avatar, token: token, referredBy: referredBy);
}

class AuthToken extends AuthServiceModel {
  ObjectId get id => this['_modelId'];
  AuthUser get user => this['user'];

  AuthToken({required AuthUser user}) : super({'user': user});

  AuthToken.copyNew(AuthToken original, {AuthUser? user})
      : super.copyNew(original, {'user': user});

  AuthToken.copyWith(AuthToken original, {AuthUser? user})
      : super.copyWith(original, {'user': user});

  AuthToken.fromJson(data, {bool newId = false})
      : super.fromJson(data, {}, {'user'}, newId);

  AuthToken copyNew({AuthUser? user}) => AuthToken.copyNew(this, user: user);

  AuthToken copyWith({AuthUser? user}) => AuthToken.copyWith(this, user: user);
}

class AuthLink extends AuthServiceModel {
  ObjectId get id => this['_modelId'];
  AuthUser get user => this['user'];
  String get type => this['type'];
  String get code => this['code'];
  Map<String, String> get data => this['data'];

  AuthLink(
      {required AuthUser user,
      required String type,
      required String code,
      Map<String, String> data = const {}})
      : super({'user': user, 'type': type, 'code': code, 'data': data});

  AuthLink.copyNew(AuthLink original,
      {AuthUser? user, String? type, String? code, Map<String, String>? data})
      : super.copyNew(
            original, {'user': user, 'type': type, 'code': code, 'data': data});

  AuthLink.copyWith(AuthLink original,
      {AuthUser? user, String? type, String? code, Map<String, String>? data})
      : super.copyWith(
            original, {'user': user, 'type': type, 'code': code, 'data': data});

  AuthLink.fromJson(data, {bool newId = false})
      : super.fromJson(data, {'type', 'code', 'data'}, {'user'}, newId);

  AuthLink copyNew(
          {AuthUser? user,
          String? type,
          String? code,
          Map<String, String>? data}) =>
      AuthLink.copyNew(this, user: user, type: type, code: code, data: data);

  AuthLink copyWith(
          {AuthUser? user,
          String? type,
          String? code,
          Map<String, String>? data}) =>
      AuthLink.copyWith(this, user: user, type: type, code: code, data: data);
}

class AuthGroup extends AuthServiceModel {
  ObjectId get id => this['_modelId'];
  String get name => this['name'];
  AuthUser get owner => this['owner'];

  AuthGroup({required String name, required AuthUser owner})
      : super({'name': name, 'owner': owner});

  AuthGroup.copyNew(AuthGroup original, {String? name, AuthUser? owner})
      : super.copyNew(original, {'name': name, 'owner': owner});

  AuthGroup.copyWith(AuthGroup original, {String? name, AuthUser? owner})
      : super.copyWith(original, {'name': name, 'owner': owner});

  AuthGroup.fromJson(data, {bool newId = false})
      : super.fromJson(data, {'name'}, {'owner'}, newId);

  AuthGroup copyNew({String? name, AuthUser? owner}) =>
      AuthGroup.copyNew(this, name: name, owner: owner);

  AuthGroup copyWith({String? name, AuthUser? owner}) =>
      AuthGroup.copyWith(this, name: name, owner: owner);
}

class AuthMembership extends AuthServiceModel {
  ObjectId get id => this['_modelId'];
  AuthUser get user => this['user'];
  AuthGroup get group => this['group'];
  AuthUser get invitedBy => this['invitedBy'];

  AuthMembership(
      {required AuthUser user,
      required AuthGroup group,
      required AuthUser invitedBy})
      : super({'user': user, 'group': group, 'invitedBy': invitedBy});

  AuthMembership.copyNew(AuthMembership original,
      {AuthUser? user, AuthGroup? group, AuthUser? invitedBy})
      : super.copyNew(
            original, {'user': user, 'group': group, 'invitedBy': invitedBy});

  AuthMembership.copyWith(AuthMembership original,
      {AuthUser? user, AuthGroup? group, AuthUser? invitedBy})
      : super.copyWith(
            original, {'user': user, 'group': group, 'invitedBy': invitedBy});

  AuthMembership.fromJson(data, {bool newId = false})
      : super.fromJson(data, {}, {'user', 'group', 'invitedBy'}, newId);

  AuthMembership copyNew(
          {AuthUser? user, AuthGroup? group, AuthUser? invitedBy}) =>
      AuthMembership.copyNew(this,
          user: user, group: group, invitedBy: invitedBy);

  AuthMembership copyWith(
          {AuthUser? user, AuthGroup? group, AuthUser? invitedBy}) =>
      AuthMembership.copyWith(this,
          user: user, group: group, invitedBy: invitedBy);
}
