import 'dart:async';

import 'package:oobium/oobium.dart';
import 'package:oobium_server/src/server.dart';
import 'package:oobium_server/src/services/auth_service.dart';
import 'package:oobium_server/src/services/services.dart';

class DataConnection {

  final String path;
  final Map<String, DataStore> _datastores;
  final ServerWebSocket _socket;
  DataConnection._(this.path, this._datastores, this._socket) {
    _socket.on.put('/data/db', _onPutDatabase);
  }

  ServerWebSocket get socket => _socket;
  String get uid => _socket.id;

  Future<void> _onPutDatabase(WsRequest req, WsResponse res) async {
    print('server _onPutDatabase(${req.data.value})');
    final dbDef = DbDefinition.fromJson(req.data.value);
    final dbPath = _path(dbDef);
    int code;
    if(_datastores.containsKey(dbPath)) {
      code = 200;
    } else {
      _datastores[dbPath] = DataStore(dbDef, await Database(dbPath).open());
      code = 201;
    }
    await _datastores[dbPath].database.bind(socket, name: dbDef.name, wait: false);
    res.send(code: code);
  }

  String _path(DbDefinition dbDef) {
    if(dbDef.shared == true) {
      return '$path/groups/${dbDef.name}'; // TODO groupId ???
    } else {
      return '$path/users/$uid/${dbDef.name}';
    }
  }
}

class DataService extends Service<AuthConnection, DataConnection> {

  final String path;
  final _datastores = <String, DataStore>{};
  final _connections = <DataConnection>[];
  DataService({this.path = 'data'});

  @override
  void onAttach(AuthConnection auth) {
    final socket = auth.socket;
    final connection = DataConnection._(path, _datastores, socket);
    _connections.add(connection);
    services.attach(connection);
    socket.done.then((_) {
      _connections.remove(connection);
      services.detach(connection);
    });
  }

  @override
  void onDetach(AuthConnection host) {
    _connections.clear();
  }

  @override
  FutureOr<void> onStart() {
    return Future.value();
  }

  @override
  FutureOr<void> onStop() {
    _connections.clear();
    return Future.wait(_datastores.values.map((ds) => ds.database.close()));
  }
}
