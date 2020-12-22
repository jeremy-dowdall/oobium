import 'dart:async';

import 'package:oobium/oobium.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';

Future<void> main() async {

  setUpAll(() => TestServerClient.clean('test-data'));
  tearDownAll(() => TestServerClient.clean('test-data'));

  test('test invitation process', () async {
    final server = await TestServerClient.start('test-data/test-01', 8001);

    final admin = await AdminClient.getAdmin(8001);
    expect(admin.id, isNotEmpty);
    expect(admin.token, isNotEmpty);

    print('connecting');
    final clientA = await AuthSocket().connect(port: 8001, uid: admin.id, token: admin.token);
    print('connected');
    expect(clientA.uid, admin.id);
    expect(clientA.token, admin.token);

    print('get installCode');
    final installCode = await clientA.newInstallToken();
    print('got installCode: $installCode');
    expect(installCode.length, 6);

    await Future.delayed(Duration(seconds: 10));
    clientA.onApprove = () async {
      await Future.delayed(Duration(seconds: 10));
      return true;
    };

    final clientB = await AuthSocket().connect(port: 8001, token: installCode);
    expect(clientB.uid, isNotEmpty);
    expect(clientB.uid, isNot(clientA.uid));
    expect(clientB.token, isNotEmpty);
    expect(clientB.token, isNot(clientA.token));
  });
}

class TestServerClient {

  static Future<TestServerClient> start(String path, int port) async {
    final server = TestServerClient(spawnHybridUri('auth_socket_test_server.dart', message: ['serve', path, port]));
    await server.ready;
    return server;
  }

  static Future<void> clean(String path) {
    return TestServerClient(spawnHybridUri('auth_socket_test_server.dart', message: ['clean', path])).ready;
  }

  final _ready = Completer();
  final StreamChannel channel;
  TestServerClient(this.channel) {
    channel.stream.listen((msg) {
      if(msg == 'ready') {
        _ready.complete();
      }
    });
  }

  Future<void> get ready => _ready.future;

  // Future<int> get dbModelCount => _send<int>('/db/count/models');
  //
  // Completer completer;
  // Future<T> _send<T>(String path, [dynamic data]) async {
  //   await completer?.future;
  //   completer = Completer<T>();
  //   channel.sink.add([path, data]);
  //   return completer.future;
  // }
}
