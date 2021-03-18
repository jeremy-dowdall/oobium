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
  User get owner => this['owner'];

  Group({String name, User owner}) : super({'name': name, 'owner': owner});

  Group.copyNew(Group original, {String name, User owner})
      : super.copyNew(original, {'name': name, 'owner': owner});

  Group.copyWith(Group original, {String name, User owner})
      : super.copyWith(original, {'name': name, 'owner': owner});

  Group.fromJson(data, {bool newId = false})
      : super.fromJson(data, {'name'}, {'owner'}, newId);

  Group copyNew({String name, User owner}) =>
      Group.copyNew(this, name: name, owner: owner);

  Group copyWith({String name, User owner}) =>
      Group.copyWith(this, name: name, owner: owner);
}

class Membership extends DataModel {
  User get user => this['user'];
  Group get group => this['group'];
  User get invitedBy => this['invitedBy'];

  Membership({User user, Group group, User invitedBy})
      : super({'user': user, 'group': group, 'invitedBy': invitedBy});

  Membership.copyNew(Membership original,
      {User user, Group group, User invitedBy})
      : super.copyNew(
            original, {'user': user, 'group': group, 'invitedBy': invitedBy});

  Membership.copyWith(Membership original,
      {User user, Group group, User invitedBy})
      : super.copyWith(
            original, {'user': user, 'group': group, 'invitedBy': invitedBy});

  Membership.fromJson(data, {bool newId = false})
      : super.fromJson(data, {}, {'user', 'group', 'invitedBy'}, newId);

  Membership copyNew({User user, Group group, User invitedBy}) =>
      Membership.copyNew(this, user: user, group: group, invitedBy: invitedBy);

  Membership copyWith({User user, Group group, User invitedBy}) =>
      Membership.copyWith(this, user: user, group: group, invitedBy: invitedBy);
}
