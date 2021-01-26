import 'dart:async';

import 'package:oobium/oobium.dart';
import 'package:oobium_server/src/services/admin_service.dart';
import 'package:oobium_server/src/services/auth_service.dart';
import 'package:oobium_server/src/services/data_service.dart';
import 'package:oobium_server/src/services/user_service.dart';
import 'package:oobium_server/src/server.dart';
import 'package:stream_channel/stream_channel.dart';

Future<void> hybridMain(StreamChannel channel, dynamic message) async {

  print('server $message');

  if(message[0] == 'clean') {
    await Database.clean(message[1]);
  }
  if(message[0] == 'serve') {
    final path = '${message[1]}/test_server';
    final services = message[3] as List<String>;
    final server = Server(port: message[2]);
    server.addServices([
      AdminService(),
      if(services.contains('auth')) AuthService(root: path),
      if(services.contains('user')) UserService(root: path),
      if(services.contains('data')) DataService(path: path),
    ]);
    await server.start();
    channel.stream.listen((event) async {
      if(event == 'close') {
        print('server close');
        await server.close();
        channel.sink.add('close');
      } else {
        final result = await onMessage(path, event);
        channel.sink.add(result);
      }
    });
  }

  channel.sink.add('ready');
}

Future<List<String>> onMessage(String path, String event) async {
  final sa = event.split(':');
  print('message: $sa');
  final db = await Database('$path${sa[0]}').open();
  print(' dbPath: ${db.path}');
  switch(sa[1]) {
    case '/db/destroy':
      await db.destroy();
      return [event, '200'];
    case '/db/get':
      return [event, Json.encode(db.get(sa[2]))];
    case '/db/getAll':
      return [event, Json.encode(db.getAll())];
    case '/db/count':
      return [event, '${db.getAll().length}'];
    default:
      return [event, '404'];
  }
}
