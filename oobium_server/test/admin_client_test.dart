import 'dart:async';

import 'package:oobium/oobium.dart';
import 'package:test/test.dart';

import 'test_client.dart';

Future<void> main() async {

  setUpAll(() => TestClient.clean(root));
  tearDownAll(() => TestClient.clean(root));

  group('test users', () {
    test('create new', () async {
      final path = nextPath();
      final port = nextPort();
      final server = await TestClient.start(path, port, ['auth']);
      final user = await AdminClient(port: port).createUser('test-1');
      expect(user['id'], isNotNull);
      expect(user['token'], isNotNull);
    });
  });
}

String root = 'test-data';
int dsCount = 0;
int serverCount = 0;
String nextPath() => '$root/admin_client_test-${dsCount++}';
int nextPort() => 8000 + (serverCount++);
