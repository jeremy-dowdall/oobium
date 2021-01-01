import 'dart:async';

import 'package:oobium/src/database.dart';
import 'package:oobium/src/server/services/admin_service.dart';
import 'package:oobium/src/server/services/auth_service.dart';
import 'package:oobium/src/server/services/data_service.dart';
import 'package:oobium/src/server/server.dart';
import 'package:stream_channel/stream_channel.dart';

Future<void> hybridMain(StreamChannel channel, dynamic message) async {

  print('server $message');

  if(message[0] == 'clean') {
    await Database.clean(message[1]);
  }
  if(message[0] == 'serve') {
    final server = Server(port: message[2]);
    server.addServices([
      AdminService(),
      AuthService(path: '${message[1]}/test_server'),
      DataService(path: '${message[1]}/test_server'),
    ]);
    await server.start();
  }

  channel.sink.add('ready');
}
