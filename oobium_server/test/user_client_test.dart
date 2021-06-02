import 'package:oobium/oobium.dart';
import 'package:test/test.dart';

import 'test_client.dart';

Future<void> main() async {

  setUpAll(() => TestClient.clean(root));
  tearDownAll(() => TestClient.clean(root));

  test('sign up and connect a user connection', () async {
    final path = nextPath();
    final port = nextPort();
    final server = await TestClient.start(path, port, ['auth', 'user']);

    final clientPath = '$path/test_client';

    final user = await AdminClient(port: port).createUser('test-1');
    final authClient = await AuthClient(root: clientPath, port: port).open();
    await authClient.signIn(user['id'], user['token']);
    await authClient.connect();

    final userClient = UserClient(root: clientPath);
    await userClient.setAccount(authClient.account);
    await userClient.setSocket(authClient.socket);

    expect(userClient.user?.id, user['id']);
    expect(userClient.groups, isEmpty);

    final users = userClient.getUsers();
    expect(users.length, 1);
    expect(users.first.id, user['id']);
    expect(users.first.name, user['name']);
  });

  test('add another user', () async {
    final path = nextPath();
    final port = nextPort();
    final server = await TestClient.start(path, port, ['auth', 'user']);
    final client = await createUserClient(path: path, port: port);

    expect(client.getUsers().length, 1);

    await AdminClient(port: port).createUser('test-2');
    await Future.delayed(Duration(milliseconds: 100));

    expect(client.getUsers().length, 2);
  });

  test('add group, 2 users', () async {
    final path = nextPath();
    final port = nextPort();
    final server = await TestClient.start(path, port, ['auth', 'user']);
    final client1 = await createUserClient(path: '$path/1', port: port);
    final client2 = await createUserClient(path: '$path/2', port: port);

    final group = client2.putGroup(Group(name: 'test-group-1', owner: client2.user));
    await Future.delayed(Duration(milliseconds: 100));

    expect(client1.getMemberships(), isEmpty);
    expect(client2.getMemberships(), isEmpty);
    expect(client1.getGroups(), isEmpty);
    expect(client2.getGroups().length, 1);

    client2.putMembership(Membership(group: group, user: client1.user));
    await Future.delayed(Duration(milliseconds: 100));

    expect(client1.getMemberships().length, 1);
    expect(client2.getMemberships().length, 1);
    expect(client1.getGroups().length, 1);
    expect(client2.getGroups().length, 1);
  });

  test('add group, 2 users, fail if non-owner', () async {
    final path = nextPath();
    final port = nextPort();
    final server = await TestClient.start(path, port, ['auth', 'user']);
    final client1 = await createUserClient(path: '$path/user-1', port: port);
    final client2 = await createUserClient(path: '$path/user-2', port: port);

    client1.putGroup(Group(name: 'test-group-1', owner: client1.user));
    client1.putGroup(Group(name: 'test-group-2', owner: client2.user));
    await Future.delayed(Duration(milliseconds: 100));

    final data = await server.dsGetAll('/auth_service') as List;
    expect(data.where((e) => e['name'] == 'test-group-1').length, 1);
    expect(data.where((e) => e['name'] == 'test-group-2'), isEmpty);
    expect(client2.getGroups(), isEmpty);
  });
}

Future<AuthClient> createAuthClient({required String path, required int port, user}) async {
  user ??= await AdminClient(port: port).createUser('test-1');
  final authClient = await AuthClient(root: '$path/test-client/auth-client', port: port).open();
  await authClient.signIn(user['id'], user['token']);
  await authClient.connect();
  return authClient;
}

Future<UserClient> createUserClient({required String path, required int port, AuthClient? authClient}) async {
  authClient ??= await createAuthClient(path: path, port: port);
  final userClient = UserClient(root: '$path/test-client/user-client');
  await userClient.setAccount(authClient.account);
  await userClient.setSocket(authClient.socket);
  return userClient;
}

String root = 'test-data';
int dsCount = 0;
int serverCount = 0;
String nextPath() => '$root/user_client_test-${dsCount++}';
int nextPort() => 8000 + (serverCount++);
