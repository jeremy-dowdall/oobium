import 'package:oobium/oobium.dart';

class AuthClientData extends Database {
  AuthClientData(String path)
      : super('$path/auth_client', [(data) => Account.fromJson(data)]);
}

class Account extends DataModel {
  String get uid => this['uid'];
  String get token => this['token'];
  String get avatar => this['avatar'];
  String get description => this['description'];
  int get lastConnectedAt => this['lastConnectedAt'];
  int get lastOpenedAt => this['lastOpenedAt'];

  Account(
      {required String uid,
      String? token,
      String? avatar,
      String? description,
      int? lastConnectedAt,
      int? lastOpenedAt})
      : super({
          'uid': uid,
          'token': token,
          'avatar': avatar,
          'description': description,
          'lastConnectedAt': lastConnectedAt,
          'lastOpenedAt': lastOpenedAt
        });

  Account.copyNew(Account original,
      {String? uid,
      String? token,
      String? avatar,
      String? description,
      int? lastConnectedAt,
      int? lastOpenedAt})
      : super.copyNew(original, {
          'uid': uid,
          'token': token,
          'avatar': avatar,
          'description': description,
          'lastConnectedAt': lastConnectedAt,
          'lastOpenedAt': lastOpenedAt
        });

  Account.copyWith(Account original,
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

  Account.fromJson(data, {bool newId = false})
      : super.fromJson(
            data,
            {
              'uid',
              'token',
              'avatar',
              'description',
              'lastConnectedAt',
              'lastOpenedAt'
            },
            {},
            newId);

  Account copyNew(
          {String? uid,
          String? token,
          String? avatar,
          String? description,
          int? lastConnectedAt,
          int? lastOpenedAt}) =>
      Account.copyNew(this,
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
      Account.copyWith(this,
          uid: uid,
          token: token,
          avatar: avatar,
          description: description,
          lastConnectedAt: lastConnectedAt,
          lastOpenedAt: lastOpenedAt);
}
