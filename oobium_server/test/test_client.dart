import 'dart:async';

import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';

class TestClient {

  static Future<TestClient> start(String path, int port) async {
    final server = TestClient(spawnHybridUri('test_server.dart', message: ['serve', path, port]));
    await server.ready;
    return server;
  }

  static Future<void> clean(String path) {
    return TestClient(spawnHybridUri('test_server.dart', message: ['clean', path])).ready;
  }

  final _ready = Completer();
  final StreamChannel channel;
  TestClient(this.channel) {
    channel.stream.listen((msg) {
      if(msg == 'ready') {
        _ready.complete();
      }
    });
  }

  Future<void> get ready => _ready.future;
}
