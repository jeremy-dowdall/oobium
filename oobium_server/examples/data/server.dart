import 'dart:indexed_db';

import 'package:oobium_server/oobium_server.dart';

Future<void> main() async {
  final db = Database('server.db');

  final server = Server(port: 8001);

  server.get('/ws', [websocket((socket) {
    socket.on.get('/db', (req, res) {
      res.send(data: db.getAll());
    });
  })]);

  await server.start();
}
