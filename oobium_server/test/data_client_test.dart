import 'dart:async';

import 'package:oobium/oobium.dart';
import 'package:test/test.dart';

import 'test_client.dart';

Future<void> main() async {

  setUpAll(() => TestClient.clean(root));
  tearDownAll(() => TestClient.clean(root));

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

      final user = await AdminClient(port: port).createUser('test-1');

      expect(user['id'], isNotNull);
      expect(user['token'], isNotNull);

      await authClient.signIn(user['id'], user['token']);
      expect(authClient.auth.isSignedIn, isTrue);
      expect(authClient.isConnected, isFalse);

      await authClient.setConnectionStatus(ConnectionStatus.wifi);
      expect(authClient.isConnected, isTrue);

      final dataClient = DataClient(root: clientPath, create: () => [], builder: (root, def) => null);

      await authClient.bindAccount(dataClient.setAccount);
      await authClient.bindSocket(dataClient.setSocket);
    });
   
    test('create client with initial definitions', () async {
      final client = DataClient(
        root: nextPath(),
        create: () => [Definition(name: 'private-db')],
        builder: (root, def) => Database('$root/${def.name}')
      );

      await client.setAccount(Account(uid: 'test-user-id'));

      expect(client.db('private-db'), isNotNull);
    });
   
    test('create client with initial, name selective, database', () async {
      final client = DataClient(
        root: nextPath(),
        create: () => [Definition(name: 'db1'), Definition(name: 'db2')],
        builder: (root, def) => (def.name == 'db2') ? Database('$root/${def.name}') : null
      );

      await client.setAccount(Account(uid: 'test-user-id'));

      expect(client.db('db1'), isNull);
      expect(client.db('db2'), isNotNull);
    });
   
    test('private database, dynamic create, 1 user, 2 clients', () async {
      final path = nextPath();
      final port = nextPort();
      final server = await TestClient.start(path, port);
      final user = await AdminClient(port: port).createUser('test-1');
      final client1 = await createClient('$path/test_client_1', port, user, []);
      final client2 = await createClient('$path/test_client_2', port, user, []);

      await client1.add(Definition(name: 'private-db'));
      await Future.delayed(Duration(milliseconds: 100));

      expect(client1.schema.length, 1);
      expect(client2.schema.length, 1);
      expect(client1.db('private-db'), isNotNull);
      expect(client2.db('private-db'), isNotNull);
    });
   
    test('private database, dynamic create, 1 user, 2 clients, delayed', () async {
      final path = nextPath();
      final port = nextPort();
      final server = await TestClient.start(path, port);
      final user = await AdminClient(port: port).createUser('test-1');
      final client1 = await createClient('$path/test_client_1', port, user, []);

      await client1.add(Definition(name: 'private-db'));
      await Future.delayed(Duration(milliseconds: 100));

      expect(client1.schema.length, 1);
      expect(client1.db('private-db'), isNotNull);

      final client2 = await createClient('$path/test_client_2', port, user, []);
      await Future.delayed(Duration(milliseconds: 100));
      expect(client2.schema.length, 1);
      expect(client2.db('private-db'), isNotNull);
    });
   
    test('private database, dynamic create, 1 user, 2 clients, staggered', () async {
      final path = nextPath();
      final port = nextPort();
      final server = await TestClient.start(path, port);
      final user = await AdminClient(port: port).createUser('test-1');
      final client1 = await createClient('$path/test_client_1', port, user, []);

      await client1.add(Definition(name: 'private-db'));
      expect(client1.schema.length, 1);
      expect(client1.db('private-db'), isNotNull);

      await client1.setAccount(null);
      expect(client1.schema, isEmpty);
      expect(client1.db('private-db'), isNull);

      final client2 = await createClient('$path/test_client_2', port, user, []);
      await Future.delayed(Duration(milliseconds: 100));
      expect(client2.schema.length, 1);
      expect(client2.db('private-db'), isNotNull);
    });
   
    test('private database, dynamic create, 2 users', () async {
      final path = nextPath();
      final port = nextPort();
      final server = await TestClient.start(path, port);
      final user1 = await AdminClient(port: port).createUser('test-1');
      final user2 = await AdminClient(port: port).createUser('test-2');
      final client1 = await createClient('$path/test_client_1', port, user1, []);
      final client2 = await createClient('$path/test_client_2', port, user2, []);

      await client1.add(Definition(name: 'private-db'));

      expect(client1.schema.length, 1);
      expect(client2.schema, isEmpty);
      expect(client1.db('private-db'), isNotNull);
      expect(client2.db('private-db'), isNull);
    });
   
    test('shared database, dynamic create, 2 users', () async {
      final path = nextPath();
      final port = nextPort();
      final server = await TestClient.start(path, port);
      final user1 = await AdminClient(port: port).createUser('test-1');
      final user2 = await AdminClient(port: port).createUser('test-2');
      final group = await AdminClient(port: port).createGroup('test-group-1');
      await AdminClient(port: port).createMembership(user: user1['id'], group: group['id']);
      await AdminClient(port: port).createMembership(user: user2['id'], group: group['id']);
      final client1 = await createClient('$path/test_client_1', port, user1, []);
      final client2 = await createClient('$path/test_client_2', port, user2, []);

      await client1.add(Definition(name: 'shared-db', access: group['id']));
      await Future.delayed(Duration(milliseconds: 100));

      expect(client1.schema.length, 1);
      expect(client2.schema.length, 1);
      expect(client1.db('shared-db'), isNotNull);
      expect(client2.db('shared-db'), isNotNull);
    });
   
    test('shared database, dynamic create, 2 users, 2nd delayed', () async {
      final path = nextPath();
      final port = nextPort();
      final server = await TestClient.start(path, port);
      final user1 = await AdminClient(port: port).createUser('test-1');
      final user2 = await AdminClient(port: port).createUser('test-2');
      final group = await AdminClient(port: port).createGroup('test-group-1');
      await AdminClient(port: port).createMembership(user: user1['id'], group: group['id']);
      await AdminClient(port: port).createMembership(user: user2['id'], group: group['id']);
      final client1 = await createClient('$path/test_client_1', port, user1, []);

      await client1.add(Definition(name: 'shared-db', access: group['id']));
      expect(client1.schema.length, 1);
      expect(client1.db('shared-db'), isNotNull);

      await Future.delayed(Duration(milliseconds: 100));

      final client2 = await createClient('$path/test_client_2', port, user2, []);
      await Future.delayed(Duration(milliseconds: 100));
      expect(client2.schema.length, 1);
      expect(client2.db('shared-db'), isNotNull);
    });
   
    test('shared database, dynamic create, 2 users, staggered', () async {
      final path = nextPath();
      final port = nextPort();
      final server = await TestClient.start(path, port);
      final user1 = await AdminClient(port: port).createUser('test-1');
      final user2 = await AdminClient(port: port).createUser('test-2');
      final group = await AdminClient(port: port).createGroup('test-group-1');
      await AdminClient(port: port).createMembership(user: user1['id'], group: group['id']);
      await AdminClient(port: port).createMembership(user: user2['id'], group: group['id']);
      final client1 = await createClient('$path/test_client_1', port, user1, []);

      await client1.add(Definition(name: 'shared-db', access: group['id']));
      expect(client1.schema.length, 1);
      expect(client1.db('shared-db'), isNotNull);

      await client1.setAccount(null);
      expect(client1.schema, isEmpty);
      expect(client1.db('shared-db'), isNull);

      await Future.delayed(Duration(milliseconds: 100));

      final client2 = await createClient('$path/test_client_2', port, user2, []);
      await Future.delayed(Duration(milliseconds: 100));
      expect(client2.schema.length, 1);
      expect(client2.db('shared-db'), isNotNull);
    });
   
    test('add fails when user is not member of group', () async {
      final path = nextPath();
      final port = nextPort();
      final server = await TestClient.start(path, port);
      final user = await AdminClient(port: port).createUser('test-1');
      final group = await AdminClient(port: port).createGroup('test-1');
      final client = await createClient('$path/test_client_1', port, user, []);

      await client.add(Definition(name: 'shared-db', access: group['id']));
      await Future.delayed(Duration(milliseconds: 100));
      expect(client.schema.length, 0);
      expect(client.db('shared-db'), isNull);
    });

    test('shared database, dynamic create, 2 users, add to/remove from group', () async {
      final path = nextPath();
      final port = nextPort();
      final server = await TestClient.start(path, port);
      final user1 = await AdminClient(port: port).createUser('test-1');
      final user2 = await AdminClient(port: port).createUser('test-2');
      final group = await AdminClient(port: port).createGroup('test-group-1');
      final membership = await AdminClient(port: port).createMembership(user: user1['id'], group: group['id']);
      final client1 = await createClient('$path/test_client_1', port, user1, []);
      final client2 = await createClient('$path/test_client_2', port, user2, []);

      await client1.add(Definition(name: 'shared-db', access: group['id']));
      await Future.delayed(Duration(milliseconds: 100));
      expect(client1.schema.length, 1);
      expect(client1.db('shared-db'), isNotNull);
      expect(client2.schema, isEmpty);
      expect(client2.db('shared-db'), isNull);

      await AdminClient(port: port).createMembership(user: user2['id'], group: group['id']);
      await Future.delayed(Duration(milliseconds: 100));
      expect(client1.schema.length, 1);
      expect(client1.db('shared-db'), isNotNull);
      expect(client2.schema.length, 1);
      expect(client2.db('shared-db'), isNotNull);

      await AdminClient(port: port).removeMembership(membership['id']);
      await Future.delayed(Duration(milliseconds: 100));
      expect(client1.schema, isEmpty);
      expect(client1.db('shared-db'), isNull);
      expect(client2.schema.length, 1);
      expect(client2.db('shared-db'), isNotNull);
    });
  });
}

Future<DataClient> createClient(String path, int port, Map user, List<Definition> defs) async {
  final authClient = AuthClient(root: path, port: port);
  final dataClient = DataClient(
    root: path,
    create: () => defs,
    builder: (root, def) => Database('$root/${def.name}', [(data) => TestType1.fromJson(data)])
  );

  await authClient.init();
  await authClient.signIn(user['id'], user['token']);
  await authClient.setConnectionStatus(ConnectionStatus.wifi);
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
  TestType1.fromJson(data, {bool newId=false}) : super.fromJson(data, {'name'}, {}, newId);
  TestType1 copyNew({String name}) => TestType1.copyNew(this, name: name);
  TestType1 copyWith({String name}) => TestType1.copyWith(this, name: name);
}
