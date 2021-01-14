import 'package:oobium/oobium.dart';

class AuthData extends Database {
  AuthData(String path)
      : super('$path/auth', [
          (data) => User.fromJson(data),
          (data) => Token.fromJson(data),
          (data) => Group.fromJson(data),
          (data) => Membership.fromJson(data)
        ]);
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

  Token copyNew({User user}) => Token.copyNew(this, user: user);

  Token copyWith({User user}) => Token.copyWith(this, user: user);
}

class Group extends DataModel {
  String get name => this['name'];
  User get owner => this['owner'];

  Group({String name, User owner}) : super({'name': name, 'owner': owner});

  Group.copyNew(Group original, {String name, User owner})
      : super.copyNew(original, {'name': name, 'owner': owner});

  Group.copyWith(Group original, {String name, User owner})
      : super.copyWith(original, {'name': name, 'owner': owner});

  Group.fromJson(data)
      : super.fromJson(
          data,
          {'name'},
          {'owner'},
        );

  Group copyNew({String name, User owner}) =>
      Group.copyNew(this, name: name, owner: owner);

  Group copyWith({String name, User owner}) =>
      Group.copyWith(this, name: name, owner: owner);
}

class Membership extends DataModel {
  User get user => this['user'];
  Group get group => this['group'];

  Membership({User user, Group group}) : super({'user': user, 'group': group});

  Membership.copyNew(Membership original, {User user, Group group})
      : super.copyNew(original, {'user': user, 'group': group});

  Membership.copyWith(Membership original, {User user, Group group})
      : super.copyWith(original, {'user': user, 'group': group});

  Membership.fromJson(data)
      : super.fromJson(
          data,
          {},
          {'user', 'group'},
        );

  Membership copyNew({User user, Group group}) =>
      Membership.copyNew(this, user: user, group: group);

  Membership copyWith({User user, Group group}) =>
      Membership.copyWith(this, user: user, group: group);
}
