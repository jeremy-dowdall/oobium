import 'dart:async';

import 'package:oobium/oobium.dart';
import 'package:test/test.dart';

import 'test_client.dart';

Future<void> main() async {

  setUpAll(() => TestClient.clean(root));
  // tearDownAll(() => TestClient.clean(root));

  group('test with connection', () {
    test('sign up and connect a data connection', () async {
      final path = nextPath();
      final port = nextPort();
      final server = await TestClient.start(path, port);

      final clientPath = '$path/test_client';

      final authClient = AuthClient(root: clientPath, port: port);
      await authClient.init();
      expect(authClient.auth.state, AuthState.Anonymous);
      expect(await authClient.requestInstallCode(), isNull);

      final admin = await AdminClient(port: port).getAdmin();

      expect(admin?.uid, isNotNull);
      expect(admin?.token, isNotNull);

      print('signIn(${admin.uid}, ${admin.token})');
      await authClient.signIn(admin.uid, admin.token);
      expect(authClient.auth.isSignedIn, isTrue);
      expect(authClient.isConnected, isFalse);

      await authClient.setConnectionStatus(ConnectionStatus.wifi);
      expect(authClient.isConnected, isTrue);

      final dataClient = DataClient(
        root: clientPath,
        create: () => [DbDefinition(name: 'test')],
        builder: (root, def) => Database('$root/${def.name}')
      );

      await authClient.bindAccount(dataClient.setAccount);
      await authClient.bindSocket(dataClient.setSocket);

      expect(dataClient.isConnected, isTrue);
      expect(dataClient.isBound, isTrue);

      authClient.dispose();
    });
   
    test('private database and shared database', () async {
      final path = nextPath();
      final port = nextPort();
      final server = await TestClient.start(path, port);
      final account1 = await AdminClient(port: port).createAccount('test-1');
      final account2 = await AdminClient(port: port).createAccount('test-2');
      final client1 = await createClient('$path/test_client_1', port, account1);
      final client2 = await createClient('$path/test_client_2', port, account2);

      client1.db('private-db').put(TestType1(name: 'test-01'));
      await client1.db('private-db').flush();

      final model = client1.db('shared-db').put(TestType1(name: 'test-02'));
      await client1.db('shared-db').flush();

      final privateModels = client2.db('private-db').getAll<TestType1>().toList();
      expect(privateModels.isEmpty, isTrue);

      final sharedModels = client2.db('shared-db').getAll<TestType1>().toList();
      expect(sharedModels.length, 1);
      expect(sharedModels[0].isSameAs(model), isTrue);
    });
  });
}

Future<DataClient> createClient(String path, int port, Account account) async {
  final authClient = AuthClient(root: path, port: port);
  await authClient.init();

  print('signIn(${account.uid}, ${account.token})');
  await authClient.signIn(account.uid, account.token);
  await authClient.setConnectionStatus(ConnectionStatus.wifi);

  final dataClient = DataClient(
    root: path,
    create: () => [
      DbDefinition(name: 'private-db'),
      DbDefinition(name: 'shared-db', shared: true)
    ],
    builder: (root, def) => Database('$root/${def.name}', [(data) => TestType1.fromJson(data)])
  );

  await authClient.bindAccount(dataClient.setAccount);
  await authClient.bindSocket(dataClient.setSocket);

  return dataClient;
}

String root = 'test-data';
int dbCount = 0;
int serverCount = 0;
String nextPath() => '$root/database-sync-test-${dbCount++}';
int nextPort() => 8000 + (serverCount++);

class TestType1 extends DataModel {
  String get name => this['name'];
  TestType1({String name}) : super({'name': name});
  TestType1.copyNew(TestType1 original, {String name}) : super.copyNew(original, {'name': name});
  TestType1.copyWith(TestType1 original, {String name}) : super.copyWith(original, {'name': name});
  TestType1.fromJson(data) : super.fromJson(data, {'name'}, {});
  TestType1 copyNew({String name}) => TestType1.copyNew(this, name: name);
  TestType1 copyWith({String name}) => TestType1.copyWith(this, name: name);
}
