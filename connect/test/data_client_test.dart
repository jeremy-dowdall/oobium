import 'dart:async';

import 'package:oobium/oobium.dart';
import 'package:test/test.dart';

import '../../server/test/test_client.dart';

Future<void> main() async {

  setUpAll(() => TestClient.clean(root));
  tearDownAll(() => TestClient.clean(root));

  group('test with connection', () {
    test('create client with initial definitions', () async {
      final client = DataClient(
        root: nextPath(),
        create: () => [Definition(name: 'private-ds')],
        builder: (root, def) => DataStore('$root/${def.name}')
      );

      await client.setAccount(Account(uid: 'test-user-id'));

      expect(client.schema.length, 1);
      expect(client.schema.any((d) => d.name == 'private-ds'), isTrue);
      expect(client.ds(client.schema.firstWhere((d) => d.name == 'private-ds').id), isNotNull);
    });
   
    test('create client with initial, name selective, datastore', () async {
      final client = DataClient(
        root: nextPath(),
        create: () => [Definition(name: 'ds1'), Definition(name: 'ds2')],
        builder: (root, def) => (def.name == 'ds2') ? DataStore('$root/${def.name}') : null
      );

      await client.setAccount(Account(uid: 'test-user-id'));

      expect(client.schema.length, 2);
      expect(client.schema.any((d) => d.name == 'ds1'), isTrue);
      expect(client.schema.any((d) => d.name == 'ds2'), isTrue);
      expect(client.ds(client.schema.firstWhere((d) => d.name == 'ds1').id), isNull);
      expect(client.ds(client.schema.firstWhere((d) => d.name == 'ds2').id), isNotNull);
    });
   
    test('private datastore, dynamic create, 1 user, 2 clients', () async {
      final path = nextPath();
      final port = nextPort();
      final server = await TestClient.start(path, port, ['auth', 'data']);
      final user = await AdminClient(port: port).createUser('test-1');
      final client1 = await createClient('$path/test_client_1', port, user, []);
      final client2 = await createClient('$path/test_client_2', port, user, []);

      final privateDef = Definition(name: 'private-ds');

      await client1.add(privateDef);
      expect(client1.schema.length, 1);
      expect(client1.ds(privateDef.id), isNotNull);
      
      client2.events.listen(expectAsync1((event) {
        expect(event.added, isNotNull);
        expect(event.removed, isNull);
        expect(client2.schema.length, 1);
        expect(client2.ds(privateDef.id), isNotNull);
      }, count: 1));
    });
   
    test('private datastore, dynamic create, 1 user, 2 clients, delayed', () async {
      final path = nextPath();
      final port = nextPort();
      final server = await TestClient.start(path, port, ['auth', 'data']);
      final user = await AdminClient(port: port).createUser('test-1');
      final client1 = await createClient('$path/test_client_1', port, user, []);

      final privateDef = Definition(name: 'private-ds');

      await client1.add(privateDef);
      expect(client1.schema.length, 1);
      expect(client1.ds(privateDef.id), isNotNull);

      final client2 = await createClient('$path/test_client_2', port, user, []);
      await client2.events.first;
      expect(client2.schema.length, 1);
      expect(client2.ds(privateDef.id), isNotNull);
    });
   
    test('private datastore, dynamic create, 1 user, 2 clients, staggered', () async {
      final path = nextPath();
      final port = nextPort();
      final server = await TestClient.start(path, port, ['auth', 'data']);
      final user = await AdminClient(port: port).createUser('test-1');
      final client1 = await createClient('$path/test_client_1', port, user, []);

      final privateDef = Definition(name: 'private-ds');

      await client1.add(privateDef);
      expect(client1.schema.length, 1);
      expect(client1.ds(privateDef.id), isNotNull);

      await client1.setAccount(null);
      expect(client1.schema, isEmpty);
      expect(client1.ds(privateDef.id), isNull);

      final client2 = await createClient('$path/test_client_2', port, user, []);
      client2.events.listen(expectAsync1((event) {
        expect(client2.schema.length, 1);
        expect(client2.ds(privateDef.id), isNotNull);
      }));
    });
   
    test('private datastore, dynamic create, 2 users', () async {
      final path = nextPath();
      final port = nextPort();
      final server = await TestClient.start(path, port, ['auth', 'data']);
      final user1 = await AdminClient(port: port).createUser('test-1');
      final user2 = await AdminClient(port: port).createUser('test-2');
      final client1 = await createClient('$path/test_client_1', port, user1, []);
      final client2 = await createClient('$path/test_client_2', port, user2, []);

      final privateDef = Definition(name: 'private-ds');

      await client1.add(privateDef);
      expect(client1.schema.length, 1);
      expect(client1.ds(privateDef.id), isNotNull);
      expect(client2.schema, isEmpty);
      expect(client2.ds(privateDef.id), isNull);
    });
   
    test('shared datastore, dynamic create, 2 users, members, not owner', () async {
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

      final sharedDef = Definition(name: 'shared-ds', access: group['id']);

      await client1.add(sharedDef);
      expect(client1.schema.length, 1);
      expect(client1.ds(sharedDef.id), isNotNull);

      client2.events.listen(expectAsync1((event) {
        expect(client2.schema.length, 1);
        expect(client2.ds(sharedDef.id), isNotNull);
      }));
    });
   
    test('shared datastore, dynamic create, 2 users, 2nd delayed', () async {
      final path = nextPath();
      final port = nextPort();
      final server = await TestClient.start(path, port, ['auth', 'data']);
      final user1 = await AdminClient(port: port).createUser('test-1');
      final user2 = await AdminClient(port: port).createUser('test-2');
      final group = await AdminClient(port: port).createGroup('test-group-1', user1['id']);
      await AdminClient(port: port).createMembership(user: user1['id'], group: group['id']);
      await AdminClient(port: port).createMembership(user: user2['id'], group: group['id']);
      final client1 = await createClient('$path/test_client_1', port, user1, []);

      final sharedDef = Definition(name: 'shared-ds', access: group['id']);

      await client1.add(sharedDef);
      expect(client1.schema.length, 1);
      expect(client1.ds(sharedDef.id), isNotNull);

      final client2 = await createClient('$path/test_client_2', port, user2, []);
      await client2.events.first;
      expect(client2.schema.length, 1);
      expect(client2.ds(sharedDef.id), isNotNull);
    });
   
    test('shared datastore, dynamic create, 2 users, staggered', () async {
      final path = nextPath();
      final port = nextPort();
      final server = await TestClient.start(path, port, ['auth', 'data']);
      final user1 = await AdminClient(port: port).createUser('test-1');
      final user2 = await AdminClient(port: port).createUser('test-2');
      final group = await AdminClient(port: port).createGroup('test-group-1', user1['id']);
      await AdminClient(port: port).createMembership(user: user1['id'], group: group['id']);
      await AdminClient(port: port).createMembership(user: user2['id'], group: group['id']);
      final client1 = await createClient('$path/test_client_1', port, user1, []);

      final sharedDef = Definition(name: 'shared-ds', access: group['id']);

      await client1.add(sharedDef);
      expect(client1.schema.length, 1);
      expect(client1.ds(sharedDef.id), isNotNull);

      await client1.setAccount(null);
      expect(client1.schema, isEmpty);
      expect(client1.ds(sharedDef.id), isNull);

      final client2 = await createClient('$path/test_client_2', port, user2, []);
      await client2.events.first;
      expect(client2.schema.length, 1);
      expect(client2.ds(sharedDef.id), isNotNull);
    });
   
    test('shared datastore, dynamic create, 2 users, 1st is owner not member', () async {
      final path = nextPath();
      final port = nextPort();
      final server = await TestClient.start(path, port, ['auth', 'data']);
      final user1 = await AdminClient(port: port).createUser('test-1');
      final user2 = await AdminClient(port: port).createUser('test-2');
      final group = await AdminClient(port: port).createGroup('test-group-1', user1['id']);
      await AdminClient(port: port).createMembership(user: user2['id'], group: group['id']);
      final client1 = await createClient('$path/test_client_1', port, user1, []);
      final client2 = await createClient('$path/test_client_2', port, user2, []);

      final sharedDef = Definition(name: 'shared-ds', access: group['id']);

      await client1.add(sharedDef);
      expect(client1.schema.length, 1);
      expect(client1.ds(sharedDef.id), isNotNull);

      await client2.events.first;
      expect(client2.schema.length, 1);
      expect(client2.ds(sharedDef.id), isNotNull);
    });
   
    test('shared datastore, dynamic create, 2 users, 1st is not owner or member', () async {
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

      final sharedDef = Definition(name: 'shared-ds', access: group['id']);

      await client1.add(sharedDef);
      expect(client1.schema.length, 1);
      expect(client1.ds(sharedDef.id), isNotNull);
      expect(client2.schema, isEmpty);
      expect(client2.ds(sharedDef.id), isNull);
      client2.events.listen(expectAsync1((event) {}, count: 0));
    });

    test('shared datastore, dynamic create, 2 users, add to/remove from group', () async {
      final path = nextPath();
      final port = nextPort();
      final server = await TestClient.start(path, port, ['auth', 'data']);
      final user1 = await AdminClient(port: port).createUser('test-1');
      final user2 = await AdminClient(port: port).createUser('test-2');
      final group = await AdminClient(port: port).createGroup('test-group-1', user1['id']);
      final membership1 = await AdminClient(port: port).createMembership(user: user1['id'], group: group['id']);
      final client1 = await createClient('$path/test_client_1', port, user1, []);
      final client2 = await createClient('$path/test_client_2', port, user2, []);

      final sharedDef = Definition(name: 'shared-ds', access: group['id']);

      await client1.add(sharedDef);
      expect(client1.schema.length, 1);
      expect(client1.ds(sharedDef.id), isNotNull);
      expect(client2.schema, isEmpty);
      expect(client2.ds(sharedDef.id), isNull);

      final membership2 = await AdminClient(port: port).createMembership(user: user2['id'], group: group['id']);
      await client2.events.first;
      expect(client1.schema.length, 1);
      expect(client1.ds(sharedDef.id), isNotNull);
      expect(client2.schema.length, 1);
      expect(client2.ds(sharedDef.id), isNotNull);

      await AdminClient(port: port).removeMembership(membership1['id']);
      await client1.events.first;
      expect(client1.schema, isEmpty);
      expect(client1.ds(sharedDef.id), isNull);
      expect(client2.schema.length, 1);
      expect(client2.ds(sharedDef.id), isNotNull);

      await AdminClient(port: port).removeMembership(membership2['id']);
      await client2.events.first;
      expect(client1.schema, isEmpty);
      expect(client1.ds(sharedDef.id), isNull);
      expect(client2.schema, isEmpty);
      expect(client2.ds(sharedDef.id), isNull);
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
    builder: (root, def) => DataStore('$root/${def.name}', [(data) => TestType1.fromJson(data)])
  );

  await dataClient.setAccount(authClient.account);
  await dataClient.setSocket(authClient.socket);

  return dataClient;
}

String root = 'test-data';
int dsCount = 0;
int serverCount = 0;
String nextPath() => '$root/data_client_test-${dsCount++}';
int nextPort() => 8000 + (serverCount++);
