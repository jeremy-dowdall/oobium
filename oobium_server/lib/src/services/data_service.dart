import 'dart:async';

import 'package:oobium/oobium.dart';
import 'package:oobium_server/src/server.dart';
import 'package:oobium_server/src/services/auth_service.dart';
import 'package:oobium_server/src/services/services.dart';

class DataService extends Service<AuthService> {

  final String path;
  final _datastores = <String, DataStore>{};
  DataService({this.path = 'data'});

  @override
  void onAttach(AuthService authService) {
    final socket = authService.socket;
    socket.on.put('/data/db', _onPutDatabase(socket));
  }

  @override
  FutureOr<void> onStart() {
    return Future.value();
  }

  @override
  FutureOr<void> onStop() {
    return Future.wait(_datastores.values.map((ds) => ds.database.close()));
  }

  WsMessageHandler _onPutDatabase(ServerWebSocket socket) => (WsRequest req, WsResponse res) async {
    print('server _onPutDatabase(${req.data.value})');
    final dbDef = DbDefinition.fromJson(req.data.value);
    final dbPath = _path(path, dbDef, socket);
    if(_datastores.containsKey(dbPath)) {
      res.send(code: 200);
    } else {
      _datastores[dbPath] = DataStore(dbDef, await Database(dbPath).open());
      res.send(code: 201);
    }
    print('server bind:${dbDef.name}');
    return _datastores[dbPath].database.bind(socket, wait: false);
  };

  String _path(String root, DbDefinition dbDef, ServerWebSocket socket) {
    if(dbDef.shared == true) {
      return '$path/${socket.id}/${dbDef.name}';
    } else {
      return '$path/${dbDef.name}'; // TODO groupId ???
    }
  }
}
