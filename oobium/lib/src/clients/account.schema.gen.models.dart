import 'package:oobium/oobium.dart';

class AccountData extends Database {
  AccountData(String path)
      : super('$path/account', [(data) => Account.fromJson(data)]);
}

class Account extends DataModel {
  String get uid => this['uid'];
  String get token => this['token'];

  Account({String uid, String token}) : super({'uid': uid, 'token': token});

  Account.copyNew(Account original, {String uid, String token})
      : super.copyNew(original, {'uid': uid, 'token': token});

  Account.copyWith(Account original, {String uid, String token})
      : super.copyWith(original, {'uid': uid, 'token': token});

  Account.fromJson(data)
      : super.fromJson(
          data,
          {'uid', 'token'},
          {},
        );

  Account copyNew({String uid, String token}) =>
      Account.copyNew(this, uid: uid, token: token);

  Account copyWith({String uid, String token}) =>
      Account.copyWith(this, uid: uid, token: token);
}
