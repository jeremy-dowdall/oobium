import 'package:oobium_datastore/oobium_datastore.dart';

class AuthServiceData {
  final DataStore _ds;
  AuthServiceData(String path, {DataStoreObserver? observer})
      : _ds = DataStore('$path/auth_service',
            adapters: Adapters([
              Adapter<AuthUser>(
                  decode: (m) {
                    if (m['token'] != null) {
                      m['token'] = DataId(m['token']);
                    }
                    if (m['referredBy'] != null) {
                      m['referredBy'] = DataId(m['referredBy']);
                    }
                    return AuthUser._(m);
                  },
                  encode: (k, v) => v,
                  fields: ['name', 'avatar', 'token', 'referredBy']),
              Adapter<AuthToken>(
                  decode: (m) {
                    m['user'] = DataId(m['user']);
                    return AuthToken._(m);
                  },
                  encode: (k, v) => v,
                  fields: ['user']),
              Adapter<AuthLink>(
                  decode: (m) {
                    m['user'] = DataId(m['user']);
                    m['data'] = Map<String, String>.from(m['data'] ?? {});
                    return AuthLink._(m);
                  },
                  encode: (k, v) => v,
                  fields: ['user', 'type', 'code', 'data']),
              Adapter<AuthGroup>(
                  decode: (m) {
                    m['owner'] = DataId(m['owner']);
                    return AuthGroup._(m);
                  },
                  encode: (k, v) => v,
                  fields: ['name', 'owner']),
              Adapter<AuthMembership>(
                  decode: (m) {
                    m['user'] = DataId(m['user']);
                    m['group'] = DataId(m['group']);
                    m['invitedBy'] = DataId(m['invitedBy']);
                    return AuthMembership._(m);
                  },
                  encode: (k, v) => v,
                  fields: ['user', 'group', 'invitedBy'])
            ]),
            indexes: [],
            observer: observer);
  Future<AuthServiceData> open(
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
  List<AuthUser> getAuthUsers({bool Function(AuthUser model)? where}) =>
      _ds.getAll<AuthUser>(where: where);
  List<AuthToken> getAuthTokens({bool Function(AuthToken model)? where}) =>
      _ds.getAll<AuthToken>(where: where);
  List<AuthLink> getAuthLinks({bool Function(AuthLink model)? where}) =>
      _ds.getAll<AuthLink>(where: where);
  List<AuthGroup> getAuthGroups({bool Function(AuthGroup model)? where}) =>
      _ds.getAll<AuthGroup>(where: where);
  List<AuthMembership> getAuthMemberships(
          {bool Function(AuthMembership model)? where}) =>
      _ds.getAll<AuthMembership>(where: where);
  List<AuthUser> findAuthUsers(
          {String? name,
          String? avatar,
          AuthToken? token,
          AuthUser? referredBy}) =>
      _ds.getAll<AuthUser>(
          where: (m) =>
              (name == null || name == m.name) &&
              (avatar == null || avatar == m.avatar) &&
              (token == null || token == m.token) &&
              (referredBy == null || referredBy == m.referredBy));
  List<AuthToken> findAuthTokens({AuthUser? user}) =>
      _ds.getAll<AuthToken>(where: (m) => (user == null || user == m.user));
  List<AuthLink> findAuthLinks(
          {AuthUser? user,
          String? type,
          String? code,
          Map<String, String>? data}) =>
      _ds.getAll<AuthLink>(
          where: (m) =>
              (user == null || user == m.user) &&
              (type == null || type == m.type) &&
              (code == null || code == m.code) &&
              (data == null || data == m.data));
  List<AuthGroup> findAuthGroups({String? name, AuthUser? owner}) =>
      _ds.getAll<AuthGroup>(
          where: (m) =>
              (name == null || name == m.name) &&
              (owner == null || owner == m.owner));
  List<AuthMembership> findAuthMemberships(
          {AuthUser? user, AuthGroup? group, AuthUser? invitedBy}) =>
      _ds.getAll<AuthMembership>(
          where: (m) =>
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
  AuthServiceModel.deleted(AuthServiceModel original) : super.deleted(original);
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

  AuthUser._(map) : super(map);

  AuthUser._copyNew(AuthUser original,
      {required String name,
      String? avatar,
      AuthToken? token,
      AuthUser? referredBy})
      : super.copyNew(original, {
          'name': name,
          'avatar': avatar,
          'token': token,
          'referredBy': referredBy
        });

  AuthUser._copyWith(AuthUser original,
      {String? name, String? avatar, AuthToken? token, AuthUser? referredBy})
      : super.copyWith(original, {
          'name': name,
          'avatar': avatar,
          'token': token,
          'referredBy': referredBy
        });

  AuthUser._deleted(AuthUser original) : super.deleted(original);

  AuthUser copyNew(
          {required String name,
          String? avatar,
          AuthToken? token,
          AuthUser? referredBy}) =>
      AuthUser._copyNew(this,
          name: name, avatar: avatar, token: token, referredBy: referredBy);

  AuthUser copyWith(
          {String? name,
          String? avatar,
          AuthToken? token,
          AuthUser? referredBy}) =>
      AuthUser._copyWith(this,
          name: name, avatar: avatar, token: token, referredBy: referredBy);

  @override
  AuthUser deleted() => AuthUser._deleted(this);
}

class AuthToken extends AuthServiceModel {
  ObjectId get id => this['_modelId'];
  AuthUser get user => this['user'];

  AuthToken({required AuthUser user}) : super({'user': user});

  AuthToken._(map) : super(map);

  AuthToken._copyNew(AuthToken original, {required AuthUser user})
      : super.copyNew(original, {'user': user});

  AuthToken._copyWith(AuthToken original, {AuthUser? user})
      : super.copyWith(original, {'user': user});

  AuthToken._deleted(AuthToken original) : super.deleted(original);

  AuthToken copyNew({required AuthUser user}) =>
      AuthToken._copyNew(this, user: user);

  AuthToken copyWith({AuthUser? user}) => AuthToken._copyWith(this, user: user);

  @override
  AuthToken deleted() => AuthToken._deleted(this);
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

  AuthLink._(map) : super(map);

  AuthLink._copyNew(AuthLink original,
      {required AuthUser user,
      required String type,
      required String code,
      Map<String, String> data = const {}})
      : super.copyNew(
            original, {'user': user, 'type': type, 'code': code, 'data': data});

  AuthLink._copyWith(AuthLink original,
      {AuthUser? user, String? type, String? code, Map<String, String>? data})
      : super.copyWith(
            original, {'user': user, 'type': type, 'code': code, 'data': data});

  AuthLink._deleted(AuthLink original) : super.deleted(original);

  AuthLink copyNew(
          {required AuthUser user,
          required String type,
          required String code,
          Map<String, String> data = const {}}) =>
      AuthLink._copyNew(this, user: user, type: type, code: code, data: data);

  AuthLink copyWith(
          {AuthUser? user,
          String? type,
          String? code,
          Map<String, String>? data}) =>
      AuthLink._copyWith(this, user: user, type: type, code: code, data: data);

  @override
  AuthLink deleted() => AuthLink._deleted(this);
}

class AuthGroup extends AuthServiceModel {
  ObjectId get id => this['_modelId'];
  String get name => this['name'];
  AuthUser get owner => this['owner'];

  AuthGroup({required String name, required AuthUser owner})
      : super({'name': name, 'owner': owner});

  AuthGroup._(map) : super(map);

  AuthGroup._copyNew(AuthGroup original,
      {required String name, required AuthUser owner})
      : super.copyNew(original, {'name': name, 'owner': owner});

  AuthGroup._copyWith(AuthGroup original, {String? name, AuthUser? owner})
      : super.copyWith(original, {'name': name, 'owner': owner});

  AuthGroup._deleted(AuthGroup original) : super.deleted(original);

  AuthGroup copyNew({required String name, required AuthUser owner}) =>
      AuthGroup._copyNew(this, name: name, owner: owner);

  AuthGroup copyWith({String? name, AuthUser? owner}) =>
      AuthGroup._copyWith(this, name: name, owner: owner);

  @override
  AuthGroup deleted() => AuthGroup._deleted(this);
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

  AuthMembership._(map) : super(map);

  AuthMembership._copyNew(AuthMembership original,
      {required AuthUser user,
      required AuthGroup group,
      required AuthUser invitedBy})
      : super.copyNew(
            original, {'user': user, 'group': group, 'invitedBy': invitedBy});

  AuthMembership._copyWith(AuthMembership original,
      {AuthUser? user, AuthGroup? group, AuthUser? invitedBy})
      : super.copyWith(
            original, {'user': user, 'group': group, 'invitedBy': invitedBy});

  AuthMembership._deleted(AuthMembership original) : super.deleted(original);

  AuthMembership copyNew(
          {required AuthUser user,
          required AuthGroup group,
          required AuthUser invitedBy}) =>
      AuthMembership._copyNew(this,
          user: user, group: group, invitedBy: invitedBy);

  AuthMembership copyWith(
          {AuthUser? user, AuthGroup? group, AuthUser? invitedBy}) =>
      AuthMembership._copyWith(this,
          user: user, group: group, invitedBy: invitedBy);

  @override
  AuthMembership deleted() => AuthMembership._deleted(this);
}
