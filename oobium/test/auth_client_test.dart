import 'dart:async';

import 'package:oobium/src/clients/admin_client.dart';
import 'package:oobium/src/clients/auth_client.dart';
import 'package:test/test.dart';

import 'test_client.dart';

Future<void> main() async {

  setUpAll(() => TestClient.clean(root));
  tearDownAll(() => TestClient.clean(root));

  group('test with connection', () {
    test('something', () async {
      final path = nextPath();
      final port = nextPort();
      final server = await TestClient.start(path, port);
      final client = AuthClient(port: port, root: root);
      await client.init();
      expect(client.auth.state, AuthState.Anonymous);
      expect(await client.requestInstallCode(), isNull);

      final admin = await AdminClient(port: port).getAccount();

      expect(admin?.uid, isNotNull);
      expect(admin?.token, isNotNull);

      print('signIn(${admin.uid}, ${admin.token})');
      await client.signIn(admin.uid, admin.token);
      expect(client.isConnected, isTrue);
      expect(client.auth.isSignedIn, isTrue);

      client.dispose();
    });
  });
}

String root = 'test-data';
int dbCount = 0;
int serverCount = 0;
String nextPath() => '$root/database-sync-test-${dbCount++}';
int nextPort() => 8000 + (serverCount++);
