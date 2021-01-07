import 'dart:io';

import 'package:oobium/oobium.dart';

import 'data.schema.gen.models.dart';

Future<void> main() async {
  final db = Database('client.db');

  final message = Message(from: User(name: 'bob'), to: User(name: 'joe'));

  // final socket = await ClientWebSocket.connect(address: '127.0.0.1', port: 8001, path: '/ws', headers: {
  //   HttpHeaders.authorizationHeader: 'Token somethingerruther'
  // });
  // socket.start();

  // final result = await socket.get('/db');
  // print(result);


  // socket.close();
}
