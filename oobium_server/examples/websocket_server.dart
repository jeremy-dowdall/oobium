import 'dart:io';

import 'package:oobium_server/oobium_server.dart';

void main() {
  final server = Server();

  server.get('/ws', [websocket((socket) {

    socket.on.get('/echo/<test>', (req, res) {
      res.send(data: 'received: ${req['test']}');
    });

  })]);

  server.start();
}
