import 'dart:io';

import 'package:oobium_common/oobium_common.dart';

Future<void> main() async {
  final db = Database('client.db');

  final socket = await ClientWebSocket.connect(address: '127.0.0.1', port: 8001, path: '/ws', headers: {
    HttpHeaders.authorizationHeader: 'Token somethingerruther'
  });
  socket.start();

  final result = await socket.get('/db');
  print(result);

  socket.close();
}
