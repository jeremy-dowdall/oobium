import 'dart:async';

import 'package:oobium/oobium.dart';
import 'package:oobium/src/clients/auth_client.dart';
import 'package:test/test.dart';

import 'test_client.dart';

Future<void> main() async {

  setUpAll(() => TestClient.clean(root));
  tearDownAll(() => TestClient.clean(root));

  test('initial settings', () {
    final client = AuthClient(root: nextPath());
    expect(client.isAnonymous, isTrue);
    expect(client.isSignedIn, isFalse);
    expect(client.isOpen, isFalse);
    expect(client.isConnected, isFalse);
    expect(client.account, isNull);
    expect(client.accounts, isEmpty);
  });

  test('open settings', () async {
    final client = await AuthClient(root: nextPath()).open();
    expect(client.isAnonymous, isTrue);
    expect(client.isSignedIn, isFalse);
    expect(client.isOpen, isTrue);
    expect(client.isConnected, isFalse);
    expect(client.account, isNull);
    expect(client.accounts, isEmpty);
  });

  test('sign in', () async {
    final path = nextPath();
    final port = nextPort();
    final server = await TestClient.start(path, port, ['auth']);
    final client = await AuthClient(root: path, port: port).open();

    final user = await AdminClient(port: port).createUser('test-1');
    await client.signIn(user['id'], user['token']);

    expect(client.isConnected, isFalse);
    expect(client.isSignedIn, isTrue);
    expect(client.account.uid, user['id']);
    expect(client.account.token, user['token']);
    expect(client.account.lastConnectedAt, isNull);
    expect(client.account.lastOpenedAt, isNotNull);
  });

  test('sign in and connect', () async {
    final path = nextPath();
    final port = nextPort();
    final server = await TestClient.start(path, port, ['auth']);
    final client = await AuthClient(root: path, port: port).open();

    final user = await AdminClient(port: port).createUser('test-1');
    await client.signIn(user['id'], user['token']);
    await client.connect();

    expect(client.isConnected, isTrue);
    expect(client.isSignedIn, isTrue);
    expect(client.account.uid, user['id']);
    expect(client.account.token, user['token']);
    expect(client.account.lastConnectedAt, isNotNull);
    expect(client.account.lastOpenedAt, isNotNull);
  });

  test('sign in, sign out and back in again, without connection', () async {
    final path = nextPath();
    final port = nextPort();
    final server = await TestClient.start(path, port, ['auth']);
    final client = await AuthClient(root: path, port: port).open();

    final user = await AdminClient(port: port).createUser('test-1');
    await client.signIn(user['id'], user['token']);
    expect(client.isConnected, isFalse);
    expect(client.isSignedIn, isTrue);
    expect(client.accounts.length, 1);
    expect(client.account.lastConnectedAt, isNull);
    expect(client.account.lastOpenedAt, isNotNull);

    await client.signOut();
    expect(client.isConnected, isFalse);
    expect(client.isSignedIn, isFalse);
    expect(client.accounts, isEmpty);

    await client.signIn(user['id'], user['token']);
    expect(client.isConnected, isFalse);
    expect(client.isSignedIn, isTrue);
    expect(client.accounts.length, 1);
  });

  test('sign in, sign out and back in again, with connection', () async {
    final path = nextPath();
    final port = nextPort();
    final server = await TestClient.start(path, port, ['auth']);
    final client = await AuthClient(root: path, port: port).open();

    final user = await AdminClient(port: port).createUser('test-1');
    await client.signIn(user['id'], user['token']);
    expect(client.isConnected, isFalse);
    expect(client.isSignedIn, isTrue);
    expect(client.accounts.length, 1);

    await client.connect();
    expect(client.isConnected, isTrue);
    expect(client.isSignedIn, isTrue);
    expect(client.accounts.length, 1);
    expect(client.account.lastConnectedAt, isNotNull);

    await client.signOut();
    expect(client.isConnected, isFalse);
    expect(client.isSignedIn, isFalse);
    expect(client.accounts, isEmpty);

    await client.signIn(user['id'], user['token']);
    expect(client.isConnected, isFalse);
    expect(client.isSignedIn, isTrue);
    expect(client.accounts.length, 1);

    await client.connect();
    expect(client.isConnected, isTrue);
    expect(client.isSignedIn, isTrue);
    expect(client.accounts.length, 1);
  });

  test('sign in and connect, loose connection, then reconnect', () async {
    final path = nextPath();
    final port = nextPort();
    final server = await TestClient.start(path, port, ['auth']);
    final client = await AuthClient(root: path, port: port).open();

    final user = await AdminClient(port: port).createUser('test-1');
    await client.signIn(user['id'], user['token']);
    await client.connect();
    expect(client.isConnected, isTrue);
    expect(client.isSignedIn, isTrue);
    expect(client.accounts.length, 1);
    expect(client.account.lastConnectedAt, isNotNull);

    await server.close();
    expect(client.isConnected, isFalse);
    expect(client.isSignedIn, isTrue);
    expect(client.accounts.length, 1);

    await TestClient.start(path, port, ['auth']);
    await client.connect();
    expect(client.isConnected, isTrue);
    expect(client.isSignedIn, isTrue);
    expect(client.accounts.length, 1);
  });
}

String root = 'test-data';
int dbCount = 0;
int serverCount = 0;
String nextPath() => '$root/auth_client_test-${dbCount++}';
int nextPort() => 8000 + (serverCount++);
