import 'dart:async';

import 'package:oobium/oobium.dart' hide Group, Membership;
import 'package:oobium_server/src/server.dart';
import 'package:oobium_server/src/services/auth_service.dart';
import 'package:oobium_server/src/services/auth_service.schema.gen.models.dart';
import 'package:oobium_server/src/service.dart';

const _verbose = false;

class DataService extends Service<AuthConnection, Null> {

  final String path;
  final _clients = <String/*uid*/, DataClientData>{};
  final _sockets = <String/*uid*/, List<ServerWebSocket>>{};
  final _datastores = <String/*path*/, DataStore>{};
  DataService({this.path = 'test-data'});

  DataClientData? _shared;
  StreamSubscription? _groupsSub;
  StreamSubscription? _membershipsSub;

  @override
  Future<void> onAttach(AuthConnection auth) => _addSocket(auth.socket);

  @override
  Future<void> onDetach(AuthConnection auth) => _removeSocket(auth.socket);

  @override
  Future<void> onStart() => Future.value();

  @override
  Future<void> onStop() => Future.forEach<ServerWebSocket>(_sockets.values.expand((s) => s), (s) => _removeSocket(s));

  Future<void> _addSocket(ServerWebSocket socket) async {
    if(_verbose) print('dataService._addSocket(${socket.uid})');
    _shared ??= await _openShared();

    final uid = socket.uid;
    final dataClient = _clients[uid] ??= await _openClient(uid);
    await dataClient.bind(socket, name: SchemaName, wait: false);

    _sockets.putIfAbsent(uid, () => <ServerWebSocket>[]).add(socket);

    _groupsSub ??= services.get<AuthService>().streamGroups().listen(_onGroupsEvent);
    _membershipsSub ??= services.get<AuthService>().streamMemberships().listen(_onMembershipsEvent);
  }

  Future<void> _removeSocket(ServerWebSocket socket) async {
    if(_verbose) print('dataService._removeSocket(${socket.uid})');
    final uid = socket.uid;
    _clients[uid]!.unbind(socket, name: SchemaName);
    for(var ds in _datastores.values) {
      ds.database.unbind(socket, name: ds.id);
    }
    _sockets[uid]!.remove(socket);
    if(_sockets[uid]!.isEmpty) {
      _sockets.remove(uid);
      await _clients.remove(uid)?.close();
      if(_clients.isEmpty) {
        await _shared?.close();
        _shared = null;
        await _groupsSub?.cancel();
        _groupsSub = null;
      }
    }
  }

  Future<DataClientData> _openClient(String uid) async {
    if(_verbose) print('dataService._openClient($uid)');
    final client = await DataClientData(_path(uid, id: SchemaName)).open() as DataClientData;
    await _onClientInit(uid, client);
    await _addDefinitions(uid, client.getAll<Definition>());
    client.streamAll<Definition>().listen((event) => _onClientEvent(uid, event));
    return client;
  }

  Future<DataClientData> _openShared() async {
    if(_verbose) print('dataService._openShared()');
    final shared = await DataClientData(path).open() as DataClientData;
    shared.streamAll<Definition>().listen(_onSharedEvent);
    return shared;
  }

  Future<void> _onClientInit(String uid, DataClientData client) async {
    if(_verbose) print('dataService._onClientInit($uid, $client)');
    // all groups involving the user (as owner or member)
    final groups = services.get<AuthService>().getMemberships()
      .where((m) => ((m.user?.id == uid) || (m.group?.owner?.id == uid)))
      .map((m) => m.group?.id).toSet();

    client.batch(
      // all service definitions involving user (through a group)
      put: _shared!.getAll<Definition>()
        .where((d) => groups.contains(d.access)).toList(), // put checks if they already exist or need updating

      // all client definitions involving user, not on service
      remove: client.getAll<Definition>()
        .where((d) => groups.contains(d.access) && _shared!.none(d.access))
        .map((d) => d.id)
        .toList()
    );

    await client.flush();
  }

  Future<void> _onClientEvent(String uid, DataModelEvent<Definition> event) async {
    if(_verbose) print('dataService._onClientEvent($uid, put: ${event.puts.map((e) => e.name)}, remove: ${event.removes.map((e) => e.name)})');
    // limit to groups that the user is involved in (either as owner or member)
    final groups = services.get<AuthService>().getMemberships()
      .where((m) => ((m.user?.id == uid) || (m.group?.owner?.id == uid)))
      .map((m) => m.group?.id).toSet();

    await _addDefinitions(uid, event.puts);
    _removeDefinitions(uid, event.removes);

    _shared!.batch(
      put: event.puts.where((d) => groups.contains(d.access)).toList()
    );
  }

  /// client adds shared db -> add to service -> add to other clients (onServiceEvent) -> each sync to it's other clients
  void _onSharedEvent(DataModelEvent<Definition> event) {
    if(_verbose) print('dataService._onSharedEvent(put: ${event.puts.map((e) => e.name)}, remove: ${event.removes.map((e) => e.name)})');
    for(var uid in _clients.keys) {
      final groups = services.get<AuthService>().getMemberships()
        .where((m) => ((m.user?.id == uid) || (m.group?.owner?.id == uid)))
        .map((m) => m.group?.id).toSet();
      _clients[uid]?.batch(
        put: event.puts.where((d) => groups.contains(d.access)).toList(),
        remove: event.removes.where((d) => groups.contains(d.access)).map((d) => d.id).toList()
      );
    }
  }

  void _onGroupsEvent(DataModelEvent<Group> event) {
    if(_verbose) print('dataService._onGroupsEvent(put: ${event.puts.map((e) => e.name)}, remove: ${event.removes.map((e) => e.name)})');
    _shared!.batch(
      remove: event.removes.where((g) => _shared!.any(g.id)).map((g) => g.id).toList()
    );
  }

  void _onMembershipsEvent(DataModelEvent<Membership> event) {
    if(_verbose) print('dataService._onMembershipsEvent(put: ${event.puts.map((e) => '${e.user?.name}:${e.group?.name}')}, remove: ${event.removes.map((e) => '${e.user?.name}:${e.group?.name}')})');
    for(var membership in event.puts) {
      if(_verbose) print('  dataService._onMembershipsEvent-put(${membership.user?.name} to ${membership.group?.name})');
      final client = _clients[membership.user?.id];
      if(client != null) {
        final defs = _shared!.getAll<Definition>().where((d) => d.access == membership.group?.id);
        if(_verbose) print('  dataService._onMembershipsEvent-put($defs)');
        client.putAll(defs);
      }
    }
    for(var membership in event.removes) {
      if(_verbose) print('  dataService._onMembershipsEvent-remove(${membership.user?.name} from ${membership.group?.name})');
      final client = _clients[membership.user?.id];
      if(client != null) {
        final defs = _shared!.getAll<Definition>().where((d) => d.access == membership.group?.id);
        if(_verbose) print('  dataService._onMembershipsEvent-remove($defs)');
        client.removeAll(defs.map((d) => d.id));
      }
    }
  }

  Future<void> _addDefinitions(String uid, Iterable<Definition> defs) async {
    if(_verbose) print('dataService._addDefinitions($uid, $defs)');
    for(var def in defs) {
      await _addDefinition(uid, def);
    }
  }

  void _removeDefinitions(String uid, Iterable<Definition> defs) {
    if(_verbose) print('dataService._removeDefinitions($uid, $defs)');
    for(var def in defs) {
      _removeDefinition(uid, def);
    }
  }

  Future<void> _addDefinition(String uid, Definition def) async {
    if(_verbose) print('dataService._addDefinition(${_path(uid, def: def)})');
    final path = _path(uid, def: def);
    final ds = _datastores[path] ??= DataStore(def, await Database(path).open());
    await _bind(uid, ds);
  }

  void _removeDefinition(String uid, Definition def) {
    if(_verbose) print('dataService._removeDefinition(${_path(uid, def: def)})');
    final path = _path(uid, def: def);
    final ds = _datastores.remove(path);
    if(ds != null) {
      _unbind(uid, ds);
    }
  }

  Future<void> _bind(String uid, DataStore ds) async {
    if(_verbose) print('dataService._bind($uid, $ds)');
    for(var socket in _dsSockets(uid, ds)) {
      await ds.database.bind(socket, name: ds.id, wait: false);
    }
  }

  void _unbind(String uid, DataStore ds) {
    if(_verbose) print('dataService._unbind($uid, $ds)');
    for(var socket in _dsSockets(uid, ds)) {
      ds.database.unbind(socket, name: ds.id);
    }
  }

  List<ServerWebSocket> _dsSockets(String uid, DataStore ds) => (ds.access == null)
    ? _sockets[uid]?.toList() ?? []
    : services.get<AuthService>().getMemberships().where((m) => m.group?.id == ds.access).expand((m) => _sockets[m.user?.id] ?? <ServerWebSocket>[]).toList();

  /// '$path/$id/$name'
  String _path(String uid, {Definition? def, String? id}) {
    return '$path/${def?.access ?? uid}/${def?.id ?? id}';
  }
}
