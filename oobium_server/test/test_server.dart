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
    await DataStore.clean(message[1]);
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
  final ds = await DataStore('$path${sa[0]}').open();
  print(' dsPath: ${ds.path}');
  switch(sa[1]) {
    case '/ds/destroy':
      await ds.destroy();
      return [event, '200'];
    case '/ds/get':
      return [event, Json.encode(ds.get(sa[2]))];
    case '/ds/getAll':
      return [event, Json.encode(ds.getAll())];
    case '/ds/count':
      return [event, '${ds.getAll().length}'];
    default:
      return [event, '404'];
  }
}
