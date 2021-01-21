import 'package:oobium/oobium.dart';

class AccountData extends Database {
  AccountData(String path)
      : super('$path/account', [(data) => Account.fromJson(data)]);
}

class Account extends DataModel {
  String get uid => this['uid'];
  String get token => this['token'];
  String get avatar => this['avatar'];
  String get description => this['description'];

  Account(
      {@required String uid, String token, String avatar, String description})
      : super({
          'uid': uid,
          'token': token,
          'avatar': avatar,
          'description': description
        });

  Account.copyNew(Account original,
      {String uid, String token, String avatar, String description})
      : super.copyNew(original, {
          'uid': uid,
          'token': token,
          'avatar': avatar,
          'description': description
        });

  Account.copyWith(Account original,
      {String uid, String token, String avatar, String description})
      : super.copyWith(original, {
          'uid': uid,
          'token': token,
          'avatar': avatar,
          'description': description
        });

  Account.fromJson(data, {bool newId = false})
      : super.fromJson(
            data, {'uid', 'token', 'avatar', 'description'}, {}, newId);

  Account copyNew(
          {String uid, String token, String avatar, String description}) =>
      Account.copyNew(this,
          uid: uid, token: token, avatar: avatar, description: description);

  Account copyWith(
          {String uid, String token, String avatar, String description}) =>
      Account.copyWith(this,
          uid: uid, token: token, avatar: avatar, description: description);
}
