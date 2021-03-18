import 'package:oobium/oobium.dart';
import 'package:oobium/src/clients/auth_client.schema.gen.models.dart';
import 'package:oobium/src/websocket.dart';

class UserClient {

  final String root;
  UserClient({@required this.root});

  Account get account => _account;
  String get uid => _account.uid;
  User get user => _data.get<User>(uid);
  Iterable<Group> get groups => _data.getAll<Membership>().where((m) => m.user.id == uid).map((m) => m.group);

  User getUser(String id) => _data.get<User>(id);
  Iterable<User> getUsers() => _data.getAll<User>() ?? <User>[];
  User putUser(User user) => _data.put(user);
  Stream<DataModelEvent<User>> streamUsers({bool Function(User model) where}) => _data.streamAll<User>(where: where);

  Group getGroup(String id) => _data.get<Group>(id);
  Iterable<Group> getGroups() => _data.getAll<Group>() ?? <Group>[];
  Group putGroup(Group group) => _data.put(group);
  Stream<DataModelEvent<Group>> streamGroups({bool Function(Group model) where}) => _data.streamAll<Group>(where: where);

  Membership getMembership(String id) => _data.get<Membership>(id);
  Iterable<Membership> getMemberships() => _data.getAll<Membership>() ?? <Membership>[];
  Membership putMembership(Membership membership) => _data.put(membership);
  Stream<DataModelEvent<Membership>> streamMemberships({bool Function(Membership model) where}) => _data.streamAll<Membership>(where: where);


  Account _account;
  UserClientData _data;
  WebSocket _socket;
  
  Future<void> setAccount(Account account) async {
    if(account?.id != _account?.id) {
      if(_account != null) {
        await _data.close();
        _data = null;
      }

      _account = account;

      if(_account != null) {
        _data = await UserClientData('$root/${_account.uid}').open();
        if(_socket != null) {
          await _data.bind(_socket, name: '__users__');
        }
      }
    }
  }
  
  Future<void> setSocket(WebSocket socket) async {
    if(socket != _socket) {
      if(_socket != null) {
        _data?.unbind(_socket, name: '__users__');
      }

      _socket = socket;

      if(_socket != null) {
        await _data?.bind(_socket, name: '__users__');
      }
    }
  }
}