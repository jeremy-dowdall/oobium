import 'package:oobium_datastore/oobium_datastore.dart';

class AuthClientData {
  final DataStore _ds;
  AuthClientData(String path, {DataStoreObserver? observer})
      : _ds = DataStore('$path/auth_client',
            adapters: Adapters([
              Adapter<Account>(
                  decode: (m) => Account._(m),
                  encode: (k, v) => v,
                  fields: [
                    'uid',
                    'token',
                    'avatar',
                    'description',
                    'lastConnectedAt',
                    'lastOpenedAt'
                  ])
            ]),
            indexes: [],
            observer: observer);
  Future<AuthClientData> open(
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
  Account? getAccount(ObjectId? id, {Account? Function()? orElse}) =>
      _ds.get<Account>(id, orElse: orElse);
  List<Account> getAccounts({bool Function(Account model)? where}) =>
      _ds.getAll<Account>(where: where);
  List<Account> findAccounts(
          {String? uid,
          String? token,
          String? avatar,
          String? description,
          int? lastConnectedAt,
          int? lastOpenedAt}) =>
      _ds.getAll<Account>(
          where: (m) =>
              (uid == null || uid == m.uid) &&
              (token == null || token == m.token) &&
              (avatar == null || avatar == m.avatar) &&
              (description == null || description == m.description) &&
              (lastConnectedAt == null ||
                  lastConnectedAt == m.lastConnectedAt) &&
              (lastOpenedAt == null || lastOpenedAt == m.lastOpenedAt));
  T put<T extends AuthClientModel>(T model) => _ds.put<T>(model);
  List<T> putAll<T extends AuthClientModel>(Iterable<T> models) =>
      _ds.putAll<T>(models);
  Account putAccount(
          {required String uid,
          String? token,
          String? avatar,
          String? description,
          int lastConnectedAt = 0,
          int lastOpenedAt = 0}) =>
      _ds.put(Account(
          uid: uid,
          token: token,
          avatar: avatar,
          description: description,
          lastConnectedAt: lastConnectedAt,
          lastOpenedAt: lastOpenedAt));
  T remove<T extends AuthClientModel>(T model) => _ds.remove<T>(model);
  List<T> removeAll<T extends AuthClientModel>(Iterable<T> models) =>
      _ds.removeAll<T>(models);
  Stream<Account?> streamAccount(ObjectId id) => _ds.stream<Account>(id);
  Stream<DataModelEvent<Account>> streamAccounts(
          {bool Function(Account model)? where}) =>
      _ds.streamAll<Account>(where: where);
}

abstract class AuthClientModel extends DataModel {
  AuthClientModel([Map<String, dynamic>? fields]) : super(fields);
  AuthClientModel.copyNew(
      AuthClientModel original, Map<String, dynamic>? fields)
      : super.copyNew(original, fields);
  AuthClientModel.copyWith(
      AuthClientModel original, Map<String, dynamic>? fields)
      : super.copyWith(original, fields);
  AuthClientModel.deleted(AuthClientModel original) : super.deleted(original);
}

class Account extends AuthClientModel {
  ObjectId get id => this['_modelId'];
  String get uid => this['uid'];
  String? get token => this['token'];
  String? get avatar => this['avatar'];
  String? get description => this['description'];
  int get lastConnectedAt => this['lastConnectedAt'];
  int get lastOpenedAt => this['lastOpenedAt'];

  Account(
      {required String uid,
      String? token,
      String? avatar,
      String? description,
      int lastConnectedAt = 0,
      int lastOpenedAt = 0})
      : super({
          'uid': uid,
          'token': token,
          'avatar': avatar,
          'description': description,
          'lastConnectedAt': lastConnectedAt,
          'lastOpenedAt': lastOpenedAt
        });

  Account._(map) : super(map);

  Account._copyNew(Account original,
      {required String uid,
      String? token,
      String? avatar,
      String? description,
      int lastConnectedAt = 0,
      int lastOpenedAt = 0})
      : super.copyNew(original, {
          'uid': uid,
          'token': token,
          'avatar': avatar,
          'description': description,
          'lastConnectedAt': lastConnectedAt,
          'lastOpenedAt': lastOpenedAt
        });

  Account._copyWith(Account original,
      {String? uid,
      String? token,
      String? avatar,
      String? description,
      int? lastConnectedAt,
      int? lastOpenedAt})
      : super.copyWith(original, {
          'uid': uid,
          'token': token,
          'avatar': avatar,
          'description': description,
          'lastConnectedAt': lastConnectedAt,
          'lastOpenedAt': lastOpenedAt
        });

  Account._deleted(Account original) : super.deleted(original);

  Account copyNew(
          {required String uid,
          String? token,
          String? avatar,
          String? description,
          int lastConnectedAt = 0,
          int lastOpenedAt = 0}) =>
      Account._copyNew(this,
          uid: uid,
          token: token,
          avatar: avatar,
          description: description,
          lastConnectedAt: lastConnectedAt,
          lastOpenedAt: lastOpenedAt);

  Account copyWith(
          {String? uid,
          String? token,
          String? avatar,
          String? description,
          int? lastConnectedAt,
          int? lastOpenedAt}) =>
      Account._copyWith(this,
          uid: uid,
          token: token,
          avatar: avatar,
          description: description,
          lastConnectedAt: lastConnectedAt,
          lastOpenedAt: lastOpenedAt);

  @override
  Account deleted() => Account._deleted(this);
}
