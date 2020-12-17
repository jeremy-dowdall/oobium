import 'dart:async';

import 'package:oobium_common/src/data/data.dart';
import 'package:oobium_common/src/data/repo.dart';
import 'package:oobium_common/src/data/sync.dart';
import 'package:oobium_common/src/database.dart';
import 'package:oobium_common/src/websocket.dart';
import 'package:oobium_common_test/oobium_common_test.dart';
import 'package:test/test.dart';

Future<void> main() async {

  // setUp(() => Data(path).destroy());
  // tearDownAll(() => Data(path).destroy());

  group('lifecycle', () {
    test('test no id first open', () async {
      final path = nextPath();
      await Data(path).create();
      final sync = Sync(path, Repo(path));
      await sync.open();
      expect(sync.id, isNull);
    });

    test('test id auto-generated on replicate and maintained on open', () async {
      final path = nextPath();
      await Data(path).create();
      final sync = Sync(path, Repo(path));
      await sync.open();
      await sync.createReplicant();
      expect(sync.id, isNotNull);
      final id = sync.id;
      await sync.close();
      expect(sync.id, isNull);
      await sync.open();
      expect(sync.id, id);
    });
  });

  test('test replication', () async {
    final port = nextPort();
    final server = await serverIsolate(nextPath(), port);
    final model = await server.dbPut(TestType1(name: 'test-01'));

    final db = database(nextPath());
    await db.reset(socket: await ClientWebSocket.connect(port: port));

    expect(db.get<TestType1>(model['id'])?.name, model['name']);
  });

  test('test bind(1 <-> 2) with pre-existing data', () async {
    final port = nextPort();
    final server = await serverIsolate(nextPath(), port);
    final client = (await ClientWebSocket.connect(port: port));

    final db2 = database(nextPath());
    await db2.reset(socket: client);

    final m1 = TestType1(name: 'test01');
    final m2 = TestType1(name: 'test02');

    await server.dbPut(m1);
    db2.put(m2);

    await db2.bind(client);

    expect(await server.dbModelCount, 2);
    expect(await server.dbModelCount, db2.size);
    expect((await server.dbGet(m1.id))['name'], 'test01');
    expect((await server.dbGet(m2.id))['name'], 'test02');
    expect(db2.get<TestType1>(m1.id)?.name, 'test01');
    expect(db2.get<TestType1>(m2.id)?.name, 'test02');
  });

  test('test bind(1 <-> 2) fresh', () async {
    final port = nextPort();
    final server = await serverIsolate(nextPath(), port);
    final client = (await ClientWebSocket.connect(port: port));

    final db = database(nextPath());
    await db.reset(socket: client);

    await db.bind(client);

    final m1 = TestType1(name: 'test01');
    await server.dbPut(m1);
    expect(await server.dbModelCount, 1);
    expect(db.size, 1);
    expect(db.get(m1.id), isNotNull);
    expect(db.get<TestType1>(m1.id).name, 'test01');

    final m2 = TestType1(name: 'test02');
    db.put(m2);
    expect(db.size, 2);
    expect(await server.dbModelCount, db.size);
    expect((await server.dbGet(m2.id))['name'], 'test02');
  });

  test('test bind(2 <-> 1 <-> 3)', () async {
    final port = nextPort();
    final server = await serverIsolate(nextPath(), port);
    final client1 = (await ClientWebSocket.connect(port: port));
    final client2 = (await ClientWebSocket.connect(port: port));

    final db1 = database(nextPath());
    await db1.reset(socket: client1);
    final db2 = database('test3');
    await db2.reset(socket: client2);

    await db1.bind(client1);
    await db2.bind(client2);

    expect(await server.dbModelCount, 0);
    expect(db1.size, 0);
    expect(db2.size, 0);

    final m1 = TestType1(name: 'test01');
    await server.dbPut(m1);
    expect(await server.dbModelCount, 1);
    expect(db1.size, 1);
    expect(db2.size, 1);
    expect((await server.dbGet(m1.id))['name'], 'test01');
    expect(db1.get<TestType1>(m1.id)?.name, 'test01');
    expect(db2.get<TestType1>(m1.id)?.name, 'test01');

    final m2 = TestType1(name: 'test02');
    db1.put(m2);
    expect(await server.dbModelCount, 2);
    expect(db1.size, 2);
    expect(db2.size, 2);
    expect((await server.dbGet(m2.id))['name'], 'test02');
    expect(db1.get<TestType1>(m2.id)?.name, 'test02');
    expect(db2.get<TestType1>(m2.id)?.name, 'test02');

    final m3 = TestType1(name: 'test03');
    db2.put(m3);
    expect(await server.dbModelCount, 3);
    expect(db1.size, 3);
    expect(db2.size, 3);
    expect((await server.dbGet(m3.id))['name'], 'test03');
    expect(db1.get<TestType1>(m3.id)?.name, 'test03');
    expect(db2.get<TestType1>(m3.id)?.name, 'test03');
  });
}

Database database(String path) => Database(path, [(data) => TestType1.fromJson(data)]);
Future<TestServer> serverIsolate(String path, int port) => TestIsolate.start(TestServer(path: path, port: port));

class TestType1 extends DataModel {
  String get name => this['name'];
  TestType1({String name}) : super({'name': name});
  TestType1.copyNew(TestType1 original, {String name}) : super.copyNew(original, {'name': name});
  TestType1.copyWith(TestType1 original, {String name}) : super.copyWith(original, {'name': name});
  TestType1.fromJson(data) : super.fromJson(data, {'name'}, {});
  @override TestType1 copyNew({String name}) => TestType1.copyNew(this, name: name);
  @override TestType1 copyWith({String name}) => TestType1.copyWith(this, name: name);
}

class TestServer extends TestDatabaseServer {

  TestServer({String path, int port}) : super(path: path, port: port);

  @override
  Database onCreateDatabase() => Database(path, [(data) => TestType1.fromJson(data)]);
}

int dbCount = 0;
int serverCount = 0;
String nextPath() => 'test-data/database-sync-test-${dbCount++}';
int nextPort() => 8000 + (serverCount++);
