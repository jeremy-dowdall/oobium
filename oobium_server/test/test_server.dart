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
    final server = Server(port: message[2]);
    server.addServices([
      AdminService(),
      AuthService(path: path),
      UserService(path: path),
      DataService(path: path),
    ]);
    await server.start();
  }

  channel.sink.add('ready');
}
