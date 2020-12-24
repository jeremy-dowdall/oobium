import 'package:oobium/oobium.dart';

class AuthData extends Database {
  AuthData(String path)
      : super(path,
            [(data) => User.fromJson(data), (data) => Token.fromJson(data)]);
}

class User extends DataModel {
  String get name => this['name'];
  String get avatar => this['avatar'];
  Token get token => this['token'];
  User get referredBy => this['referredBy'];
  String get path => this['path'];
  String get role => this['role'];

  User(
      {String name,
      String avatar,
      Token token,
      User referredBy,
      String path,
      String role})
      : super({
          'name': name,
          'avatar': avatar,
          'token': token,
          'referredBy': referredBy,
          'path': path,
          'role': role
        });

  User.copyNew(User original,
      {String name,
      String avatar,
      Token token,
      User referredBy,
      String path,
      String role})
      : super.copyNew(original, {
          'name': name,
          'avatar': avatar,
          'token': token,
          'referredBy': referredBy,
          'path': path,
          'role': role
        });

  User.copyWith(User original,
      {String name,
      String avatar,
      Token token,
      User referredBy,
      String path,
      String role})
      : super.copyWith(original, {
          'name': name,
          'avatar': avatar,
          'token': token,
          'referredBy': referredBy,
          'path': path,
          'role': role
        });

  User.fromJson(data)
      : super.fromJson(
          data,
          {'name', 'avatar', 'path', 'role'},
          {'token', 'referredBy'},
        );

  @override
  User copyNew(
          {String name,
          String avatar,
          Token token,
          User referredBy,
          String path,
          String role}) =>
      User.copyNew(this,
          name: name,
          avatar: avatar,
          token: token,
          referredBy: referredBy,
          path: path,
          role: role);

  @override
  User copyWith(
          {String name,
          String avatar,
          Token token,
          User referredBy,
          String path,
          String role}) =>
      User.copyWith(this,
          name: name,
          avatar: avatar,
          token: token,
          referredBy: referredBy,
          path: path,
          role: role);
}

class Token extends DataModel {
  User get user => this['user'];

  Token({User user}) : super({'user': user});

  Token.copyNew(Token original, {User user})
      : super.copyNew(original, {'user': user});

  Token.copyWith(Token original, {User user})
      : super.copyWith(original, {'user': user});

  Token.fromJson(data)
      : super.fromJson(
          data,
          {},
          {'user'},
        );

  @override
  Token copyNew({User user}) => Token.copyNew(this, user: user);

  @override
  Token copyWith({User user}) => Token.copyWith(this, user: user);
}
