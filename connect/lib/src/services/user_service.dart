import 'dart:async';

import 'package:oobium_connect/src/clients/user_client.schema.g.dart';
import 'package:oobium_connect/src/services/auth_service.dart';
import 'package:oobium_datastore/oobium_datastore.dart';
import 'package:oobium_server/oobium_server.dart';

class UserService extends Service<AuthConnection, Null> {

  final String root;
  final _clients = <String/*uid*/, UserClientData>{};
  final _sockets = <String/*uid*/, List<ServerWebSocket>>{};
  UserService({this.root='test-data'});

  StreamSubscription? _authSub;

  @override
  Future<void> onAttach(AuthConnection auth) => _addSocket(auth.socket);

  @override
  Future<void> onDetach(AuthConnection auth) => _removeSocket(auth.socket);

  @override
  Future<void> onStart() => Future.value();

  @override
  Future<void> onStop() => Future.forEach<ServerWebSocket>(_sockets.values.expand((e) => e), (s) => _removeSocket(s));

  Future<void> _addSocket(ServerWebSocket socket) async {
    print('userService._addSocket(${socket.uid})');
    final uid = socket.uid;
    final client = _clients[uid] ??= await _openClient(uid);
    await client.bind(socket, name: '__users__', wait: false);

    _sockets.putIfAbsent(uid, () => <ServerWebSocket>[]).add(socket);

    _authSub ??= services.get<AuthService>().streamAll().listen(_onServiceEvent);
  }

  Future<void> _removeSocket(ServerWebSocket socket) async {
    print('userService._removeSocket(${socket.uid})');
    final uid = socket.uid;
    _clients[uid]?.unbind(socket, name: '__users__');
    _sockets[uid]?.remove(socket);
    if(_sockets[uid]?.isEmpty ==  true) {
      _sockets.remove(uid);
      await _clients.remove(uid)?.close();
      if(_clients.isEmpty) {
        await _authSub?.cancel();
        _authSub = null;
      }
    }
  }

  Future<UserClientData> _openClient(String uid) async {
    final client = await UserClientData('$root/$uid').open();
    await _onClientInit(uid, client);
    client.streamAll().listen(_onClientEvent(uid));
    return client;
  }

  Future<void> _onClientInit(String uid, UserClientData client) {
    final service = services.get<AuthService>();

    // all users
    final users = service.getUsers();

    // all memberships involving the user
    final memberships = service.getMemberships()
      .where((m) => (m.user?.id == uid) || (m.group?.owner?.id == uid));
    
    // all groups involving the user (as owner or member)
    final groups = service.getGroups()
      .where((g) => (g.owner?.id == uid) || memberships.any((m) => (m.group?.id == g.id) && (m.user?.id == uid)));

    client.batch(
      put: [
        ...users.map((u) => User.fromJson(u.toJson())),
        ...groups.map((g) => Group.fromJson(g.toJson())),
        ...memberships.map((m) => Membership.fromJson(m.toJson())),
      ],
      remove: client.getAll().where((e) => service.none(e.id)).map((e) => e.id).toList(),
    );

    return client.flush();
  }

  void Function(DataModelEvent event) _onClientEvent(String uid) => (event) {
    final service = services.get<AuthService>();

    // do not put client users into the service ds

    // all memberships involving the user
    final memberships = event.puts.whereType<Membership>()
      .where((m) => (m.user.id == uid) || (m.group.owner.id == uid));

    // only groups owned by the user
    final groups = event.puts.whereType<Group>()
      .where((g) => (g.owner.id == uid) || service.getMemberships().any((m) => (m.group?.id == g.id) && (m.user?.id == uid)));

    service.batch(
      put: [
        ...memberships.map((m) => s.Membership.fromJson(m.toJson())),
        ...groups.map((g) => s.Group.fromJson(g.toJson())),
      ],
      remove: event.removes.map((m) => m.id)
    );
  };

  void _onServiceEvent(DataModelEvent event) {
    final service = services.get<AuthService>();

    // all users
    final users = event.puts.whereType<s.User>();

    for(var e in _clients.entries) {
      final uid = e.key;
      final client = e.value;

      // all memberships involving the user
      final memberships = event.puts.whereType<Membership>()
        .where((m) => (m.user.id == uid) || (m.group.owner.id == uid));

      // all groups involving the user (as owner or member)
      final groups = event.puts.whereType<Group>()
        .where((g) => (g.owner.id == uid)
          || memberships.any((m) => (m.group.id == g.id) && (m.user.id == uid))               // this event
          || service.getMemberships().any((m) => (m.group.id == g.id) && (m.user.id == uid))) // the whole ds
        .followedBy(memberships.map((m) => m.group))
        .fold<Map<String, Group>>({}, (a,g) {a[g.id] = g; return a;}).values;

      client.batch(
        put: [
          ...users.map((u) => User.fromJson(u.toJson())),
          ...groups.map((g) => Group.fromJson(g.toJson())),
          ...memberships.map((m) => Membership.fromJson(m.toJson())),
        ],
        remove: event.removes.map((m) => m.id).toList()
      );
    }
  }
}
