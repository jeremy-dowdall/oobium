import 'dart:async';

import 'package:oobium/src/data/data.dart';
import 'package:oobium/src/data/repo.dart';
import 'package:oobium/src/data/sync.dart';
import 'package:oobium/src/database.dart';
import 'package:oobium/src/websocket.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';

Future<void> main() async {

  setUpAll(() => cleanHybrid('test-data'));
  tearDownAll(() => cleanHybrid('test-data'));

  group('sync lifecycle', () {
    test('test no id first open', () async {
      final path = nextPath();
      final data = await Data(path).open();
      final sync = Sync(data, Repo(data));
      await sync.open();
      expect(sync.id, isNull);
    });

    test('test id auto-generated on replicate and maintained on open', () async {
      final path = nextPath();
      final data = await Data(path).open();
      final sync = Sync(data, Repo(data));
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

  test('test replication reset', () async {
    final port = nextPort();
    final server = await serverHybrid(nextPath(), port);
    final model = await server.dbPut(TestType1(name: 'test-01'));

    final db = database(nextPath());
    await db.reset(socket: await WebSocket().connect(port: port));

    expect(db.size, 1);
    expect(db.get<TestType1>(model.id)?.name, model.name);
  });

  test('test replication bind with no data', () async {
    final port = nextPort();
    await serverHybrid(nextPath(), port);

    final db = await database(nextPath()).open();
    await db.bind(await WebSocket().connect(port: port));

    expect(db.size, 0);
  });

  test('test replication bind with server data', () async {
    final port = nextPort();
    final server = await serverHybrid(nextPath(), port);
    final model = await server.dbPut(TestType1(name: 'test-01'));

    final db = await database(nextPath()).open();
    await db.bind(await WebSocket().connect(port: port));

    expect(db.size, 1);
    expect(db.get<TestType1>(model.id)?.name, model.name);
  });

  test('test replication bind with client data', () async {
    final port = nextPort();
    final server = await serverHybrid(nextPath(), port);

    final db = await database(nextPath()).open();
    final model = db.put(TestType1(name: 'test-01'));
    await db.bind(await WebSocket().connect(port: port));

    expect(db.size, 1);
    expect(await server.dbModelCount, 1);
    expect((await server.dbGet(model.id))?.name, model.name);
  });

  test('test replication bind with mixed data', () async {
    final port = nextPort();
    final server = await serverHybrid(nextPath(), port);
    final model1 = await server.dbPut(TestType1(name: 'test-01'));

    final db = await database(nextPath()).open();
    final model2 = db.put(TestType1(name: 'test-02'));
    await db.bind(await WebSocket().connect(port: port));

    expect(db.size, 2);
    expect(db.get<TestType1>(model1.id)?.name, model1.name);
    expect(db.get<TestType1>(model2.id)?.name, model2.name);
    expect(await server.dbModelCount, 2);
    expect((await server.dbGet(model1.id))?.name, model1.name);
    expect((await server.dbGet(model2.id))?.name, model2.name);
  });

  test('test bind(1 <-> 2) with pre-existing data', () async {
    final port = nextPort();
    final server = await serverHybrid(nextPath(), port);
    final client = await WebSocket().connect(port: port);

    final db2 = database(nextPath());
    await db2.reset(socket: client);

    final m1 = TestType1(name: 'test01');
    final m2 = TestType1(name: 'test02');

    await server.dbPut(m1);
    db2.put(m2);

    await db2.bind(client);

    expect(await server.dbModelCount, 2);
    expect(await server.dbModelCount, db2.size);
    expect((await server.dbGet(m1.id)).name, 'test01');
    expect((await server.dbGet(m2.id)).name, 'test02');
    expect(db2.get<TestType1>(m1.id)?.name, 'test01');
    expect(db2.get<TestType1>(m2.id)?.name, 'test02');
  });

  test('test bind(1 <-> 2) fresh', () async {
    final port = nextPort();
    final server = await serverHybrid(nextPath(), port);
    final client = await WebSocket().connect(port: port);

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
    await db.flush();
    expect(db.size, 2);
    expect(await server.dbModelCount, db.size);
    expect((await server.dbGet(m2.id)).name, 'test02');
  });

  test('test bind(2 <-> 1 <-> 3)', () async {
    final port = nextPort();
    final server = await serverHybrid(nextPath(), port);
    final client1 = await WebSocket().connect(port: port);
    final client2 = await WebSocket().connect(port: port);

    final db1 = database(nextPath());
    await db1.reset(socket: client1);
    final db2 = database(nextPath());
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
    expect((await server.dbGet(m1.id)).name, 'test01');
    expect(db1.get<TestType1>(m1.id)?.name, 'test01');
    expect(db2.get<TestType1>(m1.id)?.name, 'test01');

    final m2 = TestType1(name: 'test02');
    db1.put(m2);
    await db1.flush();
    expect(await server.dbModelCount, 2);
    expect(db1.size, 2);
    expect(db2.size, 2);
    expect((await server.dbGet(m2.id)).name, 'test02');
    expect(db1.get<TestType1>(m2.id)?.name, 'test02');
    expect(db2.get<TestType1>(m2.id)?.name, 'test02');

    final m3 = TestType1(name: 'test03');
    db2.put(m3);
    await db2.flush();
    expect(await server.dbModelCount, 3);
    expect(db1.size, 3);
    expect(db2.size, 3);
    expect((await server.dbGet(m3.id)).name, 'test03');
    expect(db1.get<TestType1>(m3.id)?.name, 'test03');
    expect(db2.get<TestType1>(m3.id)?.name, 'test03');
  });

  test('test bind 2 databases on 1 socket', () async {
    final port = nextPort();
    final server = await serverHybrid(nextPath(), port, ['db1', 'db2']);
    final socket = await WebSocket().connect(port: port);

    final db1 = await database(nextPath()).open();
    final db2 = await database(nextPath()).open();

    await db1.bind(socket, name: 'db1');
    await db2.bind(socket, name: 'db2');
  });
}

Database database(String path) => Database(path, [(data) => TestType1.fromJson(data)]);
Future<DbTestServerClient> serverHybrid(String path, int port, [List<String> databases]) => DbTestServerClient.start(path, port, databases);
Future<void> cleanHybrid(String path) => DbTestServerClient.clean(path);

int dbCount = 0;
int serverCount = 0;
String nextPath() => 'test-data/database-sync-test-${dbCount++}';
int nextPort() => 8000 + (serverCount++);

class DbTestServerClient {

  static Future<DbTestServerClient> start(String path, int port, [List<String> databases]) async {
    final server = DbTestServerClient(spawnHybridUri('database_sync_test_server.dart', message: ['serve', path, port, databases ?? [null]]));
    await server.ready;
    return server;
  }

  static Future<void> clean(String path) {
    return DbTestServerClient(spawnHybridUri('database_sync_test_server.dart', message: ['clean', path])).ready;
  }

  final _ready = Completer();
  final StreamChannel channel;
  DbTestServerClient(this.channel) {
    channel.stream.listen((msg) {
      if(msg == 'ready') {
        _ready.complete();
      }
      else if(completer != null && !completer.isCompleted) {
        if(msg is Map) {
          completer.complete(TestType1.fromJson(msg));
        } else {
          completer.complete(msg);
        }
        completer = null;
      }
    });
  }

  Future<void> get ready => _ready.future;

  Future<TestType1> dbGet(String id) => _send<TestType1>('/db/get', id);
  Future<TestType1> dbPut(DataModel model) => _send<TestType1>('/db/put', model.toJson());

  Future<int> get dbModelCount => _send<int>('/db/count/models');

  Completer completer;
  Future<T> _send<T>(String path, [dynamic data]) async {
    await completer?.future;
    completer = Completer<T>();
    channel.sink.add([path, data]);
    return completer.future;
  }
}

class TestType1 extends DataModel {
  String get name => this['name'];
  TestType1({String name}) : super({'name': name});
  TestType1.copyNew(TestType1 original, {String name}) : super.copyNew(original, {'name': name});
  TestType1.copyWith(TestType1 original, {String name}) : super.copyWith(original, {'name': name});
  TestType1.fromJson(data, {bool newId=false}) : super.fromJson(data, {'name'}, {}, newId);
  TestType1 copyNew({String name}) => TestType1.copyNew(this, name: name);
  TestType1 copyWith({String name}) => TestType1.copyWith(this, name: name);
}
