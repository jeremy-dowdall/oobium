import 'dart:async';

import 'package:oobium/oobium.dart';
import 'package:oobium_server/src/server.dart';
import 'package:oobium_server/src/services/auth_service.dart';
import 'package:oobium_server/src/services/services.dart';

class DataService extends Service2<AuthService> {

  final String path;
  final _databases = <String, Database>{};
  DataService({this.path = 'data'});

  @override
  void onAttach(AuthService authService) {
    final socket = authService.socket;
    socket.on.put('/data/db/<name>/open', _onOpenDatabase(socket));
  }

  @override
  FutureOr<void> onStart() {
    return Future.value();
  }

  @override
  FutureOr<void> onStop() {
    return Future.wait(_databases.values.map((db) => db.close()));
  }

  WsMessageHandler _onOpenDatabase(ServerWebSocket socket) => (WsRequest req, WsResponse res) async {
    final name = req['name'];
    assert(name is String);
    if(_databases.containsKey(name)) {
      res.send(code: 200);
    } else {
      final db = Database('$path/${socket.id}/$name');
      await db.open();
      _databases[name] = db;
      res.send(code: 201);
    }
  };
}