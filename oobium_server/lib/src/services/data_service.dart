import 'dart:async';

import 'package:oobium/oobium.dart' hide Definition;
import 'package:oobium/oobium.dart' as c show Definition;
import 'package:oobium_server/src/server.dart';
import 'package:oobium_server/src/services/auth_service.dart';
import 'package:oobium_server/src/services/data_service.schema.gen.models.dart' as s;
import 'package:oobium_server/src/service.dart';

class DataService extends Service<AuthConnection, Null> {

  final String path;
  final s.DataServiceData _schema;
  final _clients = <String/*uid*/, DataClientData>{};
  final _sockets = <String/*uid*/, List<ServerWebSocket>>{};
  final _datastores = <String/*path*/, DataStore>{};
  DataService({this.path = 'data'}) : _schema = s.DataServiceData(path);

  @override
  Future<void> onAttach(AuthConnection auth) => _addSocket(auth.socket);

  @override
  Future<void> onDetach(AuthConnection auth) => _removeSocket(auth.socket);

  @override
  Future<void> onStart() => _schema.open();

  @override
  Future<void> onStop() async {
    await Future.forEach<ServerWebSocket>(_sockets.values.expand((s) => s), (s) => _removeSocket(s));
    return _schema.close();
  }

  Future<void> _addSocket(ServerWebSocket socket) async {
    final uid = socket.uid;
    final client = _clients[uid] ??= await _openClient(uid);
    await client.bind(socket, name: SchemaName, wait: false);

    _sockets.putIfAbsent(uid, () => <ServerWebSocket>[]).add(socket);
    // ignore: unawaited_futures
    socket.done.then((_) => _removeSocket(socket));
  }

  Future<void> _removeSocket(ServerWebSocket socket) async {
    final uid = socket.uid;
    _clients[uid].unbind(socket, name: SchemaName);
    for(var ds in _datastores.values) {
      ds.database.unbind(socket, name: ds.name);
    } 
    if(_sockets[uid].remove(socket) && _sockets[uid].isEmpty) {
      _sockets.remove(uid);
      return _clients.remove(uid).close();
    }
  }

  Future<DataClientData> _openClient(String uid) async {
    final client = await DataClientData(_path(uid, name: SchemaName)).open();

    final groups = services.get<AuthService>().getMemberships()
      .where((m) => m.user.id == uid)
      .map((m) => m.group.id).toSet();
    final cKeys = client.getAll<c.Definition>()
      .map((d) => _path(uid, def: d)).toSet();
    final sKeys = _schema.getAll<s.Definition>()
      .map((d) => d.key).toSet();
    client.batch(
      put: _schema.getAll<s.Definition>()
        .where((d) => ((uid == d.access) || groups.contains(d.access)) && !cKeys.contains(d.key))
        .map((d) => c.Definition(name: d.name, access: (d.access != uid) ? d.access : null)),
      remove: client.getAll<c.Definition>()
        .where((d) => !((uid == d.access) || groups.contains(d.access)) || !sKeys.contains(_path(uid, def: d)))
        .map((d) => d.id)
    );
    await client.flush();

    await _addDefinitions(uid, client.getAll<c.Definition>());
    client.streamAll<c.Definition>().listen((event) => _onDataModelEvent(uid, event));

    return client;
  }

  Future<void> _addDefinition(String uid, c.Definition def) async {
    print('_addDefinition(${_path(uid, def: def)})');
    final path = _path(uid, def: def);
    if(!_schema.getAll<s.Definition>().any((d) => d.key == path)) {
      _schema.put(s.Definition(key: path, name: def.name, access: def.access ?? uid));
    }
    final ds = _datastores[path] ??= DataStore(def, await Database(path).open());
    await _bind(uid, ds);
    await _share(uid, ds);
  }

  void _removeDefinition(String uid, c.Definition def) {
    print('_removeDefinition(${_path(uid, def: def)})');
    final path = _path(uid, def: def);
    final ds = _datastores.remove(path);
    if(ds != null) {
      _schema.remove(_schema.getAll<s.Definition>().firstWhere((d) => d.key == path).id);
      _unbind(uid, ds);
    }
  }

  Future<void> _addDefinitions(String uid, Iterable<c.Definition> defs) => Future.forEach<c.Definition>(defs, (def) => _addDefinition(uid, def));

  void _removeDefinitions(String uid, Iterable<c.Definition> defs) {
    for(var def in defs) {
      _removeDefinition(uid, def);
    }
  }

  Future<void> _onDataModelEvent(String uid, DataModelEvent<c.Definition> event) async {
    await _addDefinitions(uid, event.puts);
    _removeDefinitions(uid, event.removes);
  }

  Future<void> _bind(String uid, DataStore ds) {
    return Future.wait(_dsSockets(uid, ds).map((s) => ds.database.bind(s, name: ds.name, wait: false)));
  }

  void _unbind(String uid, DataStore ds) {
    for(var socket in _dsSockets(uid, ds)) {
      ds.database.unbind(socket, name: ds.definition.name);
    }
  }

  Future<void> _share(String uid, DataStore ds) {
    if(ds.access != null) {
      final schemas = services.get<AuthService>().getMemberships().where((m) => m.group.id == ds.access)
        .where((m) => (m.user.id != uid) && _clients.containsKey(m.user.id))
        .map((m) => _clients[m.user.id]);
      return Future.wait(schemas.map((s) => (s..put(ds.definition)).flush()));
    }
    return Future.value();
  }

  Iterable<ServerWebSocket> _dsSockets(String uid, DataStore ds) => (ds.access == null)
    ? _sockets[uid]
    : services.get<AuthService>().getMemberships().where((m) => m.group.id == ds.access).expand((m) => _sockets[m.user.id] ?? []);

  String _path(String uid, {c.Definition def, String name}) {
    return '$path/${def?.access ?? uid}/${def?.name ?? name}';
  }
}
