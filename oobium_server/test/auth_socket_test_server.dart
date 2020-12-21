import 'dart:async';

import 'package:oobium_server/oobium_server.dart';
import 'package:oobium_server/src/auth2/auth_service.dart';
import 'package:oobium_server/src/server.dart';
import 'package:stream_channel/stream_channel.dart';

Future<void> hybridMain(StreamChannel channel, dynamic message) async {

  if(message[0] == 'clean') {
    await Database.clean(message[1]);
  }
  if(message[0] == 'serve') {
    final server = Server(port: message[2]);

    final authService = AuthService(path: message[1]);
    await authService.init();
    authService.connect(server.host());

    await server.start();
  }

  // channel.stream.listen((msg) async {
  //   final result = await onMessage(msg[0], (msg.length > 1) ? msg[1] : null);
  //   channel.sink.add(result);
  // });

  channel.sink.add('ready');

}

// FutureOr onMessage(String path, [dynamic data]) async {
//   switch(path) {
//     case '/db/destroy':
//       await db.destroy();
//       return 200;
//     case '/db/get':
//       final id = data as String;
//       return db.get(id)?.toJson();
//     case '/db/put':
//       final model = TestType1.fromJson(data);
//       return db.put(model).toJson();
//     case '/db/count/models':
//       return db.getAll().length;
//     default:
//       return 404;
//   }
// }