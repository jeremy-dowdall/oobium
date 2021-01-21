import 'package:oobium/oobium.dart';

class AuthServiceData extends Database {
  AuthServiceData(String path)
      : super('$path/auth_service', [
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

  User({String name, String avatar, Token token, User referredBy})
      : super({
          'name': name,
          'avatar': avatar,
          'token': token,
          'referredBy': referredBy
        });

  User.copyNew(User original,
      {String name, String avatar, Token token, User referredBy})
      : super.copyNew(original, {
          'name': name,
          'avatar': avatar,
          'token': token,
          'referredBy': referredBy
        });

  User.copyWith(User original,
      {String name, String avatar, Token token, User referredBy})
      : super.copyWith(original, {
          'name': name,
          'avatar': avatar,
          'token': token,
          'referredBy': referredBy
        });

  User.fromJson(data, {bool newId = false})
      : super.fromJson(
            data, {'name', 'avatar'}, {'token', 'referredBy'}, newId);

  User copyNew({String name, String avatar, Token token, User referredBy}) =>
      User.copyNew(this,
          name: name, avatar: avatar, token: token, referredBy: referredBy);

  User copyWith({String name, String avatar, Token token, User referredBy}) =>
      User.copyWith(this,
          name: name, avatar: avatar, token: token, referredBy: referredBy);
}

class Token extends DataModel {
  User get user => this['user'];

  Token({User user}) : super({'user': user});

  Token.copyNew(Token original, {User user})
      : super.copyNew(original, {'user': user});

  Token.copyWith(Token original, {User user})
      : super.copyWith(original, {'user': user});

  Token.fromJson(data, {bool newId = false})
      : super.fromJson(data, {}, {'user'}, newId);

  Token copyNew({User user}) => Token.copyNew(this, user: user);

  Token copyWith({User user}) => Token.copyWith(this, user: user);
}

class Group extends DataModel {
  String get name => this['name'];

  Group({String name}) : super({'name': name});

  Group.copyNew(Group original, {String name})
      : super.copyNew(original, {'name': name});

  Group.copyWith(Group original, {String name})
      : super.copyWith(original, {'name': name});

  Group.fromJson(data, {bool newId = false})
      : super.fromJson(data, {'name'}, {}, newId);

  Group copyNew({String name}) => Group.copyNew(this, name: name);

  Group copyWith({String name}) => Group.copyWith(this, name: name);
}

class Membership extends DataModel {
  User get user => this['user'];
  Group get group => this['group'];
  User get invitedBy => this['invitedBy'];
  String get role => this['role'];

  Membership({User user, Group group, User invitedBy, String role})
      : super({
          'user': user,
          'group': group,
          'invitedBy': invitedBy,
          'role': role
        });

  Membership.copyNew(Membership original,
      {User user, Group group, User invitedBy, String role})
      : super.copyNew(original, {
          'user': user,
          'group': group,
          'invitedBy': invitedBy,
          'role': role
        });

  Membership.copyWith(Membership original,
      {User user, Group group, User invitedBy, String role})
      : super.copyWith(original, {
          'user': user,
          'group': group,
          'invitedBy': invitedBy,
          'role': role
        });

  Membership.fromJson(data, {bool newId = false})
      : super.fromJson(data, {'role'}, {'user', 'group', 'invitedBy'}, newId);

  Membership copyNew({User user, Group group, User invitedBy, String role}) =>
      Membership.copyNew(this,
          user: user, group: group, invitedBy: invitedBy, role: role);

  Membership copyWith({User user, Group group, User invitedBy, String role}) =>
      Membership.copyWith(this,
          user: user, group: group, invitedBy: invitedBy, role: role);
}
