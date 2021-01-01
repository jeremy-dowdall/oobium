import 'dart:async';

import 'package:oobium/src/clients/admin_client.dart';
import 'package:oobium/src/clients/auth_client.dart';
import 'package:oobium/src/clients/data_client.dart';
import 'package:oobium/src/database.dart';
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

      final clientPath = '$path/test_client';

      final authClient = AuthClient(root: clientPath, port: port);
      await authClient.init();
      expect(authClient.auth.state, AuthState.Anonymous);
      expect(await authClient.requestInstallCode(), isNull);

      final admin = await AdminClient(port: port).getAccount();

      expect(admin?.uid, isNotNull);
      expect(admin?.token, isNotNull);

      print('signIn(${admin.uid}, ${admin.token})');
      await authClient.signIn(admin.uid, admin.token);
      expect(authClient.auth.isSignedIn, isTrue);
      expect(authClient.isConnected, isFalse);

      await authClient.setConnectionStatus(ConnectionStatus.wifi);
      expect(authClient.isConnected, isTrue);

      final dataClient = DataClient(root: clientPath, builder: (path) {
        print('client: build $path');
        return Database(path);
      });

      await authClient.bindAccount(dataClient.setAccount);
      await authClient.bindSocket(dataClient.setSocket);

      expect(dataClient.isConnected, isTrue);
      expect(dataClient.isBound, isTrue);

      authClient.dispose();
    });
  });
}

String root = 'test-data';
int dbCount = 0;
int serverCount = 0;
String nextPath() => '$root/database-sync-test-${dbCount++}';
int nextPort() => 8000 + (serverCount++);
