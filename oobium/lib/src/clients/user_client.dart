import 'package:objectid/objectid.dart';
import 'package:oobium/oobium.dart';
import 'package:oobium/src/websocket.dart';

class UserClient {

  final String root;
  UserClient({required this.root});

  Account? get account => _account;
  ObjectId? get uid => (_account != null) ? ObjectId.fromHexString(_account!.uid) : null;
  User? get user => _data!.getUser(uid);
  Iterable<Group> get groups => _data!.getMemberships().where((m) => m.user.id == uid).map((m) => m.group);

  User? getUser(ObjectId id) => _data!.getUser(id);
  Iterable<User> getUsers() => _data!.getUsers();
  User putUser(User user) => _data!.put(user);
  Stream<User?> streamUser(ObjectId id) => _data!.streamUser(id);
  Stream<DataModelEvent<User>> streamUsers({bool Function(User model)? where}) => _data!.streamUsers(where: where);

  Group? getGroup(ObjectId id) => _data!.getGroup(id);
  Iterable<Group> getGroups() => _data!.getGroups();
  Group putGroup(Group group) => _data!.put(group);
  Stream<Group?> streamGroup(ObjectId id) => _data!.streamGroup(id);
  Stream<DataModelEvent<Group>> streamGroups({bool Function(Group model)? where}) => _data!.streamGroups(where: where);

  Membership? getMembership(ObjectId id) => _data!.getMembership(id);
  Iterable<Membership> getMemberships() => _data!.getMemberships();
  Membership putMembership(Membership membership) => _data!.put(membership);
  Stream<Membership?> streamMembership(ObjectId id) => _data!.streamMembership(id);
  Stream<DataModelEvent<Membership>> streamMemberships({bool Function(Membership model)? where}) => _data!.streamMemberships(where: where);


  Account? _account;
  UserClientData? _data;
  WebSocket? _socket;
  
  Future<void> setAccount(Account? account) async {
    if(account?.id != _account?.id) {
      if(_account != null) {
        await _data?.close();
        _data = null;
      }

      _account = account;

      if(_account != null) {
        _data = await UserClientData('$root/${_account!.uid}').open();
        if(_socket != null) {
          // TODO binding
          // await _data!.bind(_socket!, name: '__users__');
        }
      }
    }
  }
  
  Future<void> setSocket(WebSocket? socket) async {
    if(socket != _socket) {
      if(_socket != null) {
        // TODO binding
        // _data?.unbind(_socket!, name: '__users__');
      }

      _socket = socket;

      if(_socket != null) {
        // TODO binding
        // await _data?.bind(_socket!, name: '__users__');
      }
    }
  }
}