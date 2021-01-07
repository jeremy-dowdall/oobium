import 'dart:async';

import 'package:oobium/oobium.dart';
import 'package:oobium_test/oobium_test.dart';
import 'package:stream_channel/stream_channel.dart';

Future<void> hybridMain(StreamChannel channel, dynamic message) async {

  if(message[0] == 'clean') {
    await Database.clean(message[1]);
  }
  if(message[0] == 'serve') {
    final server = AuthAppTestServer();
    await server.start(message[1], message[2]);
    server.listen(channel);
  }

  channel.sink.add('ready');
}

class AuthAppTestServer {

  TestWebsocketServer server;

  Future<void> start(String path, int port) async {
    await TestWebsocketServer.start(port: port, onUpgrade: (socket) async {
    });
  }

  StreamSubscription listen(StreamChannel channel) {
    return channel.stream.listen((msg) async {
      final result = await onMessage(msg[0], (msg.length > 1) ? msg[1] : null);
      channel.sink.add(result);
    });
  }

  FutureOr onMessage(String path, [dynamic data]) async {
    switch(path) {
      case '/todo':
        return 200;
      default:
        return 404;
    }
  }
}
