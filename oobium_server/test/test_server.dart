import 'dart:async';

import 'package:oobium_server/oobium_server.dart';
import 'package:oobium_server/src/services/auth_service.dart';
import 'package:oobium_server/src/server.dart';
import 'package:stream_channel/stream_channel.dart';

Future<void> hybridMain(StreamChannel channel, dynamic message) async {

  if(message[0] == 'clean') {
    await Database.clean(message[1]);
  }
  if(message[0] == 'serve') {
    final server = Server(port: message[2]);
    server.addServices([
      AdminService(),
      AuthService(path: message[1]),
      DataService(path: message[1]),
    ]);
    await server.start();
  }

  channel.sink.add('ready');
}
