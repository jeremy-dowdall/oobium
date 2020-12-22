import 'dart:async';

import 'package:oobium/src/database.dart';
import 'package:oobium_test/oobium_test.dart';
import 'package:stream_channel/stream_channel.dart';

import 'database_sync_test.dart';

Future<void> hybridMain(StreamChannel channel, dynamic message) async {

  if(message[0] == 'clean') {
    await Database.clean(message[1]);
  }
  if(message[0] == 'serve') {
    final server = DbTestServer();
    await server.start(message[1], message[2]);
    server.listen(channel);
  }

  channel.sink.add('ready');
}

class DbTestServer {

  Database db;
  TestWebsocketServer server;

  Future<void> start(String path, int port) async {
    db = Database(path, [(data) => TestType1.fromJson(data)]);
    await db.reset();

    await TestWebsocketServer.start(port: port, onUpgrade: (socket) async {
      db.bind(socket);
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
      case '/db/destroy':
        await db.destroy();
        return 200;
      case '/db/get':
        final id = data as String;
        return db.get(id)?.toJson();
      case '/db/put':
        final model = TestType1.fromJson(data);
        return db.put(model).toJson();
      case '/db/count/models':
        return db.getAll().length;
      default:
        return 404;
    }
  }
}