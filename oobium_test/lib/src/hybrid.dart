import 'dart:async';

import 'package:oobium/oobium.dart';
import 'package:oobium_test/src/websocket.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';

abstract class DatabaseServerHybrid extends TestHybrid {

  Future<Map<String, dynamic>> dbGet(String id) => send<Map<String, dynamic>>('/db/get', id);
  Future<Map<String, dynamic>> dbPut(DataModel model) => send<Map<String, dynamic>>('/db/put', model);

  Future<int> get dbModelCount => send<int>('/db/count/models');

  Future<void> destroy() async {
    await send('/db/destroy');
    return stop();
  }

  final String path;
  final int port;
  DatabaseServerHybrid({this.path, this.port});

  Database _db;
  TestWebsocketServer _server;

  Database onCreateDatabase();

  @override
  Future<void> onStart() async {
    _db = onCreateDatabase();
    await _db.reset();
    _server = await TestWebsocketServer.start(port: port, onUpgrade: (socket) async {
      _db.bind(socket);
    });
  }

  @override
  Future<void> onStop() {
    return _server.close();
  }

  @override
  FutureOr onMessage(String path, data) {
    if(path == '/db/destroy') return _db?.destroy();
    if(path == '/db/get') return _db?.get(data as String)?.toJson();
    if(path == '/db/put') return _db?.put(data as DataModel)?.toJson();
    if(path == '/db/count/models') return _db?.getAll()?.length ?? 0;
  }
}

abstract class TestHybrid {

  static Future<T> start<T extends TestHybrid>(T local, String declaration) async {
    local._hybrid = _TestHybrid._(
      spawnHybridCode('''
        import 'package:stream_channel/stream_channel.dart';

        hybridMain(StreamChannel channel, Object message) async {
          final runner = $declaration;

          await for(var msg in channel.stream) {
            if(msg[0] == '_start_') {
              await runner.onStart();
              channel.sink.add(200);
            }
            else if(runner != null) {
              channel.sink.add(await runner.onMessage(msg[0], msg[1]));
            }
            else {
              channel.sink.add(404);
            }
          }

          await runner.onStart();
          channel.sink.add(200);
        }
      ''')
    );
    await local._hybrid.send('_start_');
    return local;
  }

  Future<void> onStart();
  Future<void> onStop();
  FutureOr<dynamic> onMessage(String path, dynamic data);

  Future<void> stop() {
    return _hybrid.stop();
  }

  _TestHybrid _hybrid;
  Future<T> send<T>(String path, [dynamic data]) => _hybrid.send<T>(path, data);
}

class _TestHybrid {
  final StreamChannel channel;
  _TestHybrid._(this.channel);

  Future<void> stop() async {
    channel.sink.close();
  }

  Future<T> send<T>(String path, [dynamic data]) async {
    channel.sink.add([path, data]);
    return await channel.stream.first as T;
  }
}
