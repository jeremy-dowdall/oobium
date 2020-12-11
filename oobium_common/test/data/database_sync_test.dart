import 'dart:async';
import 'dart:io';

import 'package:oobium_common/src/data/database.dart';
import 'package:oobium_common/src/websocket.dart';
import 'package:oobium_common_test/oobium_common_test.dart';
import 'package:test/test.dart';

Future<void> main() async {

  final path = 'test-data';
  final directory = Directory(path);
  if(await directory.exists()) {
    await directory.delete(recursive: true);
  }

  setUp(() async => await directory.create(recursive: true));
  tearDown(() async => await directory.delete(recursive: true));

  test('test no id on open', () async {
    final db1 = Database('$path/test1.db')
      ..addBuilder<TestType1>((data) => TestType1.fromJson(data));
    await db1.open();
    expect(db1.id, isNull);
  });

  test('test no id on reset', () async {
    final db1 = Database('$path/test1.db', [(data) => TestType1.fromJson(data)]);
    await db1.reset();
    expect(db1.id, isNull);
  });

  test('test id auto-generated on replicate and maintained on open', () async {
    final db1 = Database('$path/test1.db', [(data) => TestType1.fromJson(data)]);
    await db1.replicate();
    expect(db1.id, isNotNull);
    final id = db1.id;
    await db1.close();
    expect(db1.id, isNull);
    await db1.open();
    expect(db1.id, id);
  });

  test('test local replication', () async {
    final db1 = Database('$path/test1.db', [(data) => TestType1.fromJson(data)]);
    await db1.reset();
    expect(db1.id, isNull);

    final db2 = Database('$path/test2.db', [(data) => TestType1.fromJson(data)]);
    await db2.reset();
    expect(db2.id, isNull);

    final model1 = db1.put(TestType1(name: 'test01'));
    expect(db1.size, 1);

    await db2.reset(stream: await db1.replicate());

    final model2 = db2.get<TestType1>(model1.id);
    expect(model2, isNotNull);
    expect(model1.name, model2.name);

    await db2.close();
    await db2.open();
    final model3 = db2.get<TestType1>(model1.id);
    expect(model3, isNotNull);
    expect(model1.name, model2.name);

    await db1.destroy();
    await db2.destroy();

    expect(await directory.list().toList(), isEmpty);
  });

  test('test remote replication', () async {
    final server = await TestIsolate.start(TestServer(path: '$path/test1.db', port: 8001));
    final model = await server.dbPut(TestType1(name: 'test-01'));

    final db = Database('$path/test2.db', [(data) => TestType1.fromJson(data)]);
    await db.reset(socket: await ClientWebSocket.connect(port: 8001));

    expect(db.get<TestType1>(model['id'])?.name, model['name']);

    await server.destroy();
    await db.destroy();

    expect(await directory.list().toList(), isEmpty);
  });

  test('test bind(1 <-> 2) with pre-existing data', () async {
    final server = await TestIsolate.start(TestServer(path: '$path/test1.db', port: 8001));
    final client = (await ClientWebSocket.connect(port: 8001));

    final db2 = Database('$path/test2.db', [(data) => TestType1.fromJson(data)]);
    await db2.reset(socket: client);
    expect(db2.id, isNotNull);

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

    await server.destroy();
    await db2.destroy();

    expect(await directory.list().toList(), isEmpty);
  });

  test('test bind(1 <-> 2) fresh', () async {
    final server = await TestIsolate.start(TestServer(path: '$path/test1.db', port: 8001));
    final client = (await ClientWebSocket.connect(port: 8001));

    final db = Database('$path/test2.db', [(data) => TestType1.fromJson(data)]);
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

    await server.destroy();
    await db.destroy();

    expect(await directory.list().toList(), isEmpty);
  });

  test('test bind(2 <-> 1 <-> 3)', () async {
    final server = await TestIsolate.start(TestServer(path: '$path/test1.db', port: 8001));
    final client1 = (await ClientWebSocket.connect(port: 8001));
    final client2 = (await ClientWebSocket.connect(port: 8001));
    
    final db1 = Database('$path/test2.db', [(data) => TestType1.fromJson(data)]);
    await db1.reset(socket: client1);
    final db2 = Database('$path/test3.db', [(data) => TestType1.fromJson(data)]);
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

    await server.destroy();
    await db1.destroy();
    await db2.destroy();

    expect(await directory.list().toList(), isEmpty);
  });
}

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
  FutureOr<void> onConfigure(Database db) {
    db.addBuilder<TestType1>((data) => TestType1.fromJson(data));
  }

}
