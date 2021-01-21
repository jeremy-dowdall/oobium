import 'package:oobium/oobium.dart';

class AuthClientData extends Database {
  AuthClientData(String path)
      : super('$path/auth_client', [
          (data) => User.fromJson(data),
          (data) => Group.fromJson(data),
          (data) => Membership.fromJson(data)
        ]);
}

class User extends DataModel {
  String get name => this['name'];
  String get avatar => this['avatar'];

  User({@required String name, String avatar})
      : super({'name': name, 'avatar': avatar});

  User.copyNew(User original, {String name, String avatar})
      : super.copyNew(original, {'name': name, 'avatar': avatar});

  User.copyWith(User original, {String name, String avatar})
      : super.copyWith(original, {'name': name, 'avatar': avatar});

  User.fromJson(data, {bool newId = false})
      : super.fromJson(data, {'name', 'avatar'}, {}, newId);

  User copyNew({String name, String avatar}) =>
      User.copyNew(this, name: name, avatar: avatar);

  User copyWith({String name, String avatar}) =>
      User.copyWith(this, name: name, avatar: avatar);
}

class Group extends DataModel {
  String get name => this['name'];
  User get owner => this['owner'];

  Group({@required String name, @required User owner})
      : super({'name': name, 'owner': owner});

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

  Membership({@required User user, @required Group group})
      : super({'user': user, 'group': group});

  Membership.copyNew(Membership original, {User user, Group group})
      : super.copyNew(original, {'user': user, 'group': group});

  Membership.copyWith(Membership original, {User user, Group group})
      : super.copyWith(original, {'user': user, 'group': group});

  Membership.fromJson(data, {bool newId = false})
      : super.fromJson(data, {}, {'user', 'group'}, newId);

  Membership copyNew({User user, Group group}) =>
      Membership.copyNew(this, user: user, group: group);

  Membership copyWith({User user, Group group}) =>
      Membership.copyWith(this, user: user, group: group);
}
