import 'package:oobium_common/src/database.dart';
import 'package:oobium_common_test/oobium_common_test.dart';
import 'package:stream_channel/stream_channel.dart';

import 'database_sync_test.dart';

hybridMain(StreamChannel channel, dynamic message) async {

  final db = Database(message[0], [(data) => TestType1.fromJson(data)]);
  await db.reset();

  await TestWebsocketServer.start(port: message[1], onUpgrade: (socket) async {
    db.bind(socket);
  });

  channel.stream.listen((msg) async {
    switch(msg[0]) {
      case '/db/destroy':
        await db.destroy();
        channel.sink.add(200);
        break;
      case '/db/get':
        final id = msg[1] as String;
        channel.sink.add(await db.get(id)?.toJson());
        break;
      case '/db/put':
        final model = TestType1.fromJson(msg[1]);
        channel.sink.add(await db.put(model).toJson());
        break;
      case '/db/count/models':
        channel.sink.add(await db.getAll().length);
        break;
      default:
        channel.sink.add(404);
        break;
    }
  });

  channel.sink.add('ready');
}
