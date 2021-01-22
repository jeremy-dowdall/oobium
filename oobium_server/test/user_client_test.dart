import 'package:oobium/oobium.dart';
import 'package:test/test.dart';

import 'test_client.dart';

Future<void> main() async {

  setUpAll(() => TestClient.clean(root));
  tearDownAll(() => TestClient.clean(root));

  test('sign up and connect a data connection', () async {
    final path = nextPath();
    final port = nextPort();
    final server = await TestClient.start(path, port);

    final clientPath = '$path/test_client';

    final user = await AdminClient(port: port).createUser('test-1');
    final authClient = AuthClient(root: clientPath, port: port);
    await authClient.init();
    await authClient.signIn(user['id'], user['token']);
    await authClient.setConnectionStatus(ConnectionStatus.wifi);

    final userClient = UserClient(root: clientPath);
    await authClient.bindAccount(userClient.setAccount);
    await authClient.bindSocket(userClient.setSocket);

    expect(userClient.user.id, user['id']);
    expect(userClient.groups, isEmpty);

    final users = userClient.getUsers();
    expect(users.length, 1);
    expect(users.first.id, user['id']);
    expect(users.first.name, user['name']);
  });

  test('add another user', () async {
    final path = nextPath();
    final port = nextPort();
    final server = await TestClient.start(path, port);
    final client = await createClient(path, port);

    expect(client.getUsers().length, 1);

    print('create test-2');
    await AdminClient(port: port).createUser('test-2');
    await Future.delayed(Duration(milliseconds: 100));

    expect(client.getUsers().length, 2);
  });

  test('add group, 2 users', () async {
    final path = nextPath();
    final port = nextPort();
    final server = await TestClient.start(path, port);
    final client1 = await createClient(path, port);
    final client2 = await createClient(path, port);

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
}

Future<UserClient> createClient(String path, int port) async {
  final clientPath = '$path/test_client';

  final user = await AdminClient(port: port).createUser('test-1');
  final authClient = AuthClient(root: clientPath, port: port);
  await authClient.init();
  await authClient.signIn(user['id'], user['token']);
  await authClient.setConnectionStatus(ConnectionStatus.wifi);

  final userClient = UserClient(root: clientPath);
  await authClient.bindAccount(userClient.setAccount);
  await authClient.bindSocket(userClient.setSocket);

  return userClient;
}

String root = 'test-data';
int dbCount = 0;
int serverCount = 0;
String nextPath() => '$root/database-sync-test-${dbCount++}';
int nextPort() => 8000 + (serverCount++);
