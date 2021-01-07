import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:oobium_flutter/oobium_flutter.dart';
import 'package:stream_channel/stream_channel.dart';

Future<void> main() async {

  setUpAll(() => AuthAppTestClient.clean(root));
  tearDownAll(() => AuthAppTestClient.clean(root));

  group('test with connection', () {
    testWidgets('something', (tester) async {
      final path = nextPath();
      final server = await AuthAppTestClient.start(path, nextPort());
      await tester.pumpWidget(AuthenticatedApp(
        root: () => path,
        data: null,
        builder: null,
      ));
    });
  });
}

String root = 'test-data';
int dbCount = 0;
int serverCount = 0;
String nextPath() => '$root/database-sync-test-${dbCount++}';
int nextPort() => 8000 + (serverCount++);

class AuthAppTestClient {

  static Future<AuthAppTestClient> start(String path, int port) async {
    final server = AuthAppTestClient(spawnHybridUri('auth_app_test_server.dart', message: ['serve', path, port]));
    await server.ready;
    return server;
  }

  static Future<void> clean(String path) {
    return AuthAppTestClient(spawnHybridUri('auth_app_test_server.dart', message: ['clean', path])).ready;
  }

  final _ready = Completer();
  final StreamChannel channel;
  AuthAppTestClient(this.channel) {
    channel.stream.listen((msg) {
      if(msg == 'ready') {
        _ready.complete();
      }
      else if(completer != null && !completer.isCompleted) {
        // if(msg is Map) {
        //   completer.complete(TestType1.fromJson(msg));
        // } else {
          completer.complete(msg);
        // }
        completer = null;
      }
    });
  }

  Future<void> get ready => _ready.future;

  // Future<TestType1> dbGet(String id) => _send<TestType1>('/db/get', id);
  // Future<TestType1> dbPut(DataModel model) => _send<TestType1>('/db/put', model.toJson());
  // Future<int> get dbModelCount => _send<int>('/db/count/models');

  Completer completer;
  Future<T> _send<T>(String path, [dynamic data]) async {
    await completer?.future;
    completer = Completer<T>();
    channel.sink.add([path, data]);
    return completer.future;
  }
}
