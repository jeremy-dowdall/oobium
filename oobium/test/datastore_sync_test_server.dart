import 'dart:async';

import 'package:oobium/src/datastore.dart';
import 'package:stream_channel/stream_channel.dart';

import 'datastore_sync_test.dart';
import 'utils/test_websocket_server.dart';

Future<void> hybridMain(StreamChannel channel, dynamic message) async {

  if(message[0] == 'clean') {
    await DataStore.clean(message[1]);
  }
  if(message[0] == 'serve') {
    final server = DsTestServer();
    await server.start(message[1], message[2], message[3]);
    server.listen(channel);
  }

  channel.sink.add('ready');
}

class DsTestServer {

  late DataStore ds;

  Future<void> start(String path, int port, List<String> databases) async {
    ds = DataStore(path, [(data) => TestType1.fromJson(data)]);
    await ds.reset();

    await TestWebsocketServer.start(port: port, onUpgrade: (socket) async {
      if(databases.isEmpty) {
        await ds.bind(socket, wait: false);
      } else {
        for(var name in databases) {
          await ds.bind(socket, name: name, wait: false);
        }
      }
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
      case '/ds/destroy':
        await ds.destroy();
        return 200;
      case '/ds/get':
        final id = data as String;
        return ds.get(id)?.toJson();
      case '/ds/put':
        final model = TestType1.fromJson(data);
        final result = ds.put(model).toJson();
        await ds.flush();
        return result;
      case '/ds/count/models':
        return ds.getAll().length;
      default:
        return 404;
    }
  }
}
