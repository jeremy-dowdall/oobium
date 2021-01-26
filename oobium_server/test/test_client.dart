import 'dart:async';
import 'dart:convert';

import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';

class TestClient {

  static Future<TestClient> start(String path, int port, List<String> services) async {
    final server = TestClient(spawnHybridUri('test_server.dart', message: ['serve', path, port, services ?? []]));
    await server.ready;
    return server;
  }

  static Future<void> clean(String path) {
    return TestClient(spawnHybridUri('test_server.dart', message: ['clean', path])).ready;
  }

  final StreamChannel channel;
  final _events = <String, Completer>{};
  TestClient(this.channel) {
    _events['ready'] = Completer();
    channel.stream.listen((msg) {
      if(msg is String) {
        _events[msg]?.complete();
      }
      else if(msg is List<String>) {
        _events[msg[0]]?.complete(jsonDecode(msg[1]));
      }
    });
  }

  Future<void> get ready => _events['ready'].future;

  Future close() => _send('close');
  Future dbGet(String dbPath, String id) => _send('$dbPath:/db/get:$id');
  Future dbGetAll(String dbPath) => _send('$dbPath:/db/getAll');
  Future dbCount(String dbPath) => _send('$dbPath:/db/count');

  Future _send(String path) async {
    channel.sink.add(path);
    return (_events[path] = Completer()).future;
  }
}
