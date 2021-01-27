import 'dart:async';

import 'package:oobium/oobium.dart';
import 'package:test/test.dart';

import 'test_client.dart';

Future<void> main() async {

  setUpAll(() => TestClient.clean(root));
  tearDownAll(() => TestClient.clean(root));

  group('test with connection', () {
    test('create client with initial definitions', () async {
      final client = DataClient(
        root: nextPath(),
        create: () => [Definition(name: 'private-db')],
        builder: (root, def) => Database('$root/${def.name}')
      );

      await client.setAccount(Account(uid: 'test-user-id'));

      expect(client.schema.length, 1);
      expect(client.schema.any((d) => d.name == 'private-db'), isTrue);
      expect(client.db(client.schema.firstWhere((d) => d.name == 'private-db').id), isNotNull);
    });
   
    test('create client with initial, name selective, database', () async {
      final client = DataClient(
        root: nextPath(),
        create: () => [Definition(name: 'db1'), Definition(name: 'db2')],
        builder: (root, def) => (def.name == 'db2') ? Database('$root/${def.name}') : null
      );

      await client.setAccount(Account(uid: 'test-user-id'));

      expect(client.schema.length, 2);
      expect(client.schema.any((d) => d.name == 'db1'), isTrue);
      expect(client.schema.any((d) => d.name == 'db2'), isTrue);
      expect(client.db(client.schema.firstWhere((d) => d.name == 'db1').id), isNull);
      expect(client.db(client.schema.firstWhere((d) => d.name == 'db2').id), isNotNull);
    });
   
    test('private database, dynamic create, 1 user, 2 clients', () async {
      final path = nextPath();
      final port = nextPort();
      final server = await TestClient.start(path, port, ['auth', 'data']);
      final user = await AdminClient(port: port).createUser('test-1');
      final client1 = await createClient('$path/test_client_1', port, user, []);
      final client2 = await createClient('$path/test_client_2', port, user, []);

      final privateDef = Definition(name: 'private-db');

      await client1.add(privateDef);
      await Future.delayed(Duration(milliseconds: 200));

      expect(client1.schema.length, 1);
      expect(client2.schema.length, 1);
      expect(client1.db(privateDef.id), isNotNull);
      expect(client2.db(privateDef.id), isNotNull);
    });
   
    test('private database, dynamic create, 1 user, 2 clients, delayed', () async {
      final path = nextPath();
      final port = nextPort();
      final server = await TestClient.start(path, port, ['auth', 'data']);
      final user = await AdminClient(port: port).createUser('test-1');
      final client1 = await createClient('$path/test_client_1', port, user, []);

      final privateDef = Definition(name: 'private-db');

      await client1.add(privateDef);
      await Future.delayed(Duration(milliseconds: 100));

      expect(client1.schema.length, 1);
      expect(client1.db(privateDef.id), isNotNull);

      final client2 = await createClient('$path/test_client_2', port, user, []);
      await Future.delayed(Duration(milliseconds: 100));
      expect(client2.schema.length, 1);
      expect(client2.db(privateDef.id), isNotNull);
    });
   
    test('private database, dynamic create, 1 user, 2 clients, staggered', () async {
      final path = nextPath();
      final port = nextPort();
      final server = await TestClient.start(path, port, ['auth', 'data']);
      final user = await AdminClient(port: port).createUser('test-1');
      final client1 = await createClient('$path/test_client_1', port, user, []);

      final privateDef = Definition(name: 'private-db');

      await client1.add(privateDef);
      expect(client1.schema.length, 1);
      expect(client1.db(privateDef.id), isNotNull);

      await client1.setAccount(null);
      expect(client1.schema, isEmpty);
      expect(client1.db(privateDef.id), isNull);

      final client2 = await createClient('$path/test_client_2', port, user, []);
      await Future.delayed(Duration(milliseconds: 100));
      expect(client2.schema.length, 1);
      expect(client2.db(privateDef.id), isNotNull);
    });
   
    test('private database, dynamic create, 2 users', () async {
      final path = nextPath();
      final port = nextPort();
      final server = await TestClient.start(path, port, ['auth', 'data']);
      final user1 = await AdminClient(port: port).createUser('test-1');
      final user2 = await AdminClient(port: port).createUser('test-2');
      final client1 = await createClient('$path/test_client_1', port, user1, []);
      final client2 = await createClient('$path/test_client_2', port, user2, []);

      final privateDef = Definition(name: 'private-db');

      await client1.add(privateDef);
      await Future.delayed(Duration(milliseconds: 100));

      expect(client1.schema.length, 1);
      expect(client2.schema, isEmpty);
      expect(client1.db(privateDef.id), isNotNull);
      expect(client2.db(privateDef.id), isNull);
    });
   
    test('shared database, dynamic create, 2 users, members, not owner', () async {
      final path = nextPath();
      final port = nextPort();
      final server = await TestClient.start(path, port, ['auth', 'data']);
      final user0 = await AdminClient(port: port).createUser('test-0');
      final user1 = await AdminClient(port: port).createUser('test-1');
      final user2 = await AdminClient(port: port).createUser('test-2');
      final group = await AdminClient(port: port).createGroup('test-group-1', user0['id']);
      await AdminClient(port: port).createMembership(user: user1['id'], group: group['id']);
      await AdminClient(port: port).createMembership(user: user2['id'], group: group['id']);
      final client1 = await createClient('$path/test_client_1', port, user1, []);
      final client2 = await createClient('$path/test_client_2', port, user2, []);

      final sharedDef = Definition(name: 'shared-db', access: group['id']);

      await client1.add(sharedDef);
      await Future.delayed(Duration(milliseconds: 100));

      expect(client1.schema.length, 1);
      expect(client2.schema.length, 1);
      expect(client1.db(sharedDef.id), isNotNull);
      expect(client2.db(sharedDef.id), isNotNull);
    });
   
    test('shared database, dynamic create, 2 users, 2nd delayed', () async {
      final path = nextPath();
      final port = nextPort();
      final server = await TestClient.start(path, port, ['auth', 'data']);
      final user1 = await AdminClient(port: port).createUser('test-1');
      final user2 = await AdminClient(port: port).createUser('test-2');
      final group = await AdminClient(port: port).createGroup('test-group-1', user1['id']);
      await AdminClient(port: port).createMembership(user: user1['id'], group: group['id']);
      await AdminClient(port: port).createMembership(user: user2['id'], group: group['id']);
      final client1 = await createClient('$path/test_client_1', port, user1, []);

      final sharedDef = Definition(name: 'shared-db', access: group['id']);

      await client1.add(sharedDef);
      expect(client1.schema.length, 1);
      expect(client1.db(sharedDef.id), isNotNull);

      await Future.delayed(Duration(milliseconds: 100));

      final client2 = await createClient('$path/test_client_2', port, user2, []);
      await Future.delayed(Duration(milliseconds: 200));
      expect(client2.schema.length, 1);
      expect(client2.db(sharedDef.id), isNotNull);
    });
   
    test('shared database, dynamic create, 2 users, staggered', () async {
      final path = nextPath();
      final port = nextPort();
      final server = await TestClient.start(path, port, ['auth', 'data']);
      final user1 = await AdminClient(port: port).createUser('test-1');
      final user2 = await AdminClient(port: port).createUser('test-2');
      final group = await AdminClient(port: port).createGroup('test-group-1', user1['id']);
      await AdminClient(port: port).createMembership(user: user1['id'], group: group['id']);
      await AdminClient(port: port).createMembership(user: user2['id'], group: group['id']);
      final client1 = await createClient('$path/test_client_1', port, user1, []);

      final sharedDef = Definition(name: 'shared-db', access: group['id']);

      await client1.add(sharedDef);
      await Future.delayed(Duration(milliseconds: 100));
      expect(client1.schema.length, 1);
      expect(client1.db(sharedDef.id), isNotNull);

      await client1.setAccount(null);
      await Future.delayed(Duration(milliseconds: 100));
      expect(client1.schema, isEmpty);
      expect(client1.db(sharedDef.id), isNull);

      final client2 = await createClient('$path/test_client_2', port, user2, []);
      await Future.delayed(Duration(milliseconds: 100));
      expect(client2.schema.length, 1);
      expect(client2.db(sharedDef.id), isNotNull);
    });
   
    test('shared database, dynamic create, 2 users, 1st is owner not member', () async {
      final path = nextPath();
      final port = nextPort();
      final server = await TestClient.start(path, port, ['auth', 'data']);
      final user1 = await AdminClient(port: port).createUser('test-1');
      final user2 = await AdminClient(port: port).createUser('test-2');
      final group = await AdminClient(port: port).createGroup('test-group-1', user1['id']);
      await AdminClient(port: port).createMembership(user: user2['id'], group: group['id']);
      final client1 = await createClient('$path/test_client_1', port, user1, []);
      final client2 = await createClient('$path/test_client_2', port, user2, []);

      final sharedDef = Definition(name: 'shared-db', access: group['id']);

      await client1.add(sharedDef);
      await Future.delayed(Duration(milliseconds: 100));

      expect(client1.schema.length, 1);
      expect(client1.db(sharedDef.id), isNotNull);
      expect(client2.schema.length, 1);
      expect(client2.db(sharedDef.id), isNotNull);
    });
   
    test('shared database, dynamic create, 2 users, 1st is not owner or member', () async {
      final path = nextPath();
      final port = nextPort();
      final server = await TestClient.start(path, port, ['auth', 'data']);
      final user0 = await AdminClient(port: port).createUser('test-0');
      final user1 = await AdminClient(port: port).createUser('test-1');
      final user2 = await AdminClient(port: port).createUser('test-2');
      final group = await AdminClient(port: port).createGroup('test-group-1', user0['id']);
      await AdminClient(port: port).createMembership(user: user2['id'], group: group['id']);
      final client1 = await createClient('$path/test_client_1', port, user1, []);
      final client2 = await createClient('$path/test_client_2', port, user2, []);

      final sharedDef = Definition(name: 'shared-db', access: group['id']);

      await client1.add(sharedDef);
      await Future.delayed(Duration(milliseconds: 100));

      expect(client1.schema.length, 1);
      expect(client2.schema, isEmpty);
      expect(client1.db(sharedDef.id), isNotNull);
      expect(client2.db(sharedDef.id), isNull);
    });

    test('shared database, dynamic create, 2 users, add to/remove from group', () async {
      final path = nextPath();
      final port = nextPort();
      final server = await TestClient.start(path, port, ['auth', 'data']);
      final user1 = await AdminClient(port: port).createUser('test-1');
      final user2 = await AdminClient(port: port).createUser('test-2');
      final group = await AdminClient(port: port).createGroup('test-group-1', user1['id']);
      final membership1 = await AdminClient(port: port).createMembership(user: user1['id'], group: group['id']);
      final client1 = await createClient('$path/test_client_1', port, user1, []);
      final client2 = await createClient('$path/test_client_2', port, user2, []);

      final sharedDef = Definition(name: 'shared-db', access: group['id']);

      await client1.add(sharedDef);
      await Future.delayed(Duration(milliseconds: 100));
      expect(client1.schema.length, 1);
      expect(client1.db(sharedDef.id), isNotNull);
      expect(client2.schema, isEmpty);
      expect(client2.db(sharedDef.id), isNull);

      final membership2 = await AdminClient(port: port).createMembership(user: user2['id'], group: group['id']);
      await Future.delayed(Duration(milliseconds: 100));
      expect(client1.schema.length, 1);
      expect(client1.db(sharedDef.id), isNotNull);
      expect(client2.schema.length, 1);
      expect(client2.db(sharedDef.id), isNotNull);

      await AdminClient(port: port).removeMembership(membership1['id']);
      await Future.delayed(Duration(milliseconds: 100));
      expect(client1.schema, isEmpty);
      expect(client1.db(sharedDef.id), isNull);
      expect(client2.schema.length, 1);
      expect(client2.db(sharedDef.id), isNotNull);

      await AdminClient(port: port).removeMembership(membership2['id']);
      await Future.delayed(Duration(milliseconds: 100));
      expect(client1.schema, isEmpty);
      expect(client1.db(sharedDef.id), isNull);
      expect(client2.schema, isEmpty);
      expect(client2.db(sharedDef.id), isNull);
    });
  });
}

Future<DataClient> createClient(String path, int port, Map user, List<Definition> defs) async {
  final authClient = await AuthClient(root: path, port: port).open();
  await authClient.signIn(user['id'], user['token']);
  await authClient.connect();

  final dataClient = DataClient(
    root: path,
    create: () => defs,
    builder: (root, def) => Database('$root/${def.name}', [(data) => TestType1.fromJson(data)])
  );

  await dataClient.setAccount(authClient.account);
  await dataClient.setSocket(authClient.socket);

  return dataClient;
}

String root = 'test-data';
int dbCount = 0;
int serverCount = 0;
String nextPath() => '$root/data_client_test-${dbCount++}';
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
