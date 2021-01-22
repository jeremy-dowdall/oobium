import 'dart:async';

import 'package:oobium/oobium.dart';
import 'package:oobium/src/clients/auth_client.dart';
import 'package:test/test.dart';

import 'test_client.dart';

Future<void> main() async {

  setUpAll(() => TestClient.clean(root));
  tearDownAll(() => TestClient.clean(root));

  group('test with connection', () {
    test('create user and sign in', () async {
      final path = nextPath();
      final port = nextPort();
      final server = await TestClient.start(path, port);
      final client = AuthClient(port: port, root: root);
      await client.init();
      await client.setConnectionStatus(ConnectionStatus.wifi);

      expect(client.auth.state, AuthState.Anonymous);
      expect(await client.requestInstallCode(), isNull);

      final user = await AdminClient(port: port).createUser('test-1');

      expect(user['id'], isNotNull);
      expect(user['token'], isNotNull);

      await client.signIn(user['id'], user['token']);
      expect(client.isConnected, isTrue);
      expect(client.auth.isSignedIn, isTrue);

      client.dispose();
    });

    test('create user, group, add user to group', () async {
      final path = nextPath();
      final port = nextPort();
      final server = await TestClient.start(path, port);
      final client = AuthClient(port: port, root: root);
      await client.init();
      await client.setConnectionStatus(ConnectionStatus.wifi);
      final user = await AdminClient(port: port).createUser('test-1');
      await client.signIn(user['id'], user['token']);

    });
  });
}

String root = 'test-data';
int dbCount = 0;
int serverCount = 0;
String nextPath() => '$root/database-sync-test-${dbCount++}';
int nextPort() => 8000 + (serverCount++);
