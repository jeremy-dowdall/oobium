import 'dart:async';
import 'dart:io';

import 'package:oobium_common/src/data/database.dart';
import 'package:oobium_common/src/websocket/websocket.dart';
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

  test('test local replication', () async {
    final db1 = Database('$path/test1.db')..addBuilder<TestType1>((data) => TestType1.fromJson(data));
    await db1.reset(uid: db1.newId());
    expect(db1.uid, isNotNull);
    expect(db1.rid, isNotNull);

    final db2 = Database('$path/test2.db')..addBuilder<TestType1>((data) => TestType1.fromJson(data));
    await db2.reset();
    expect(db2.uid, isNull);
    expect(db2.rid, isNull);

    final model1 = db1.put(TestType1(name: 'test01'));
    expect(db1.size, 1);

    await db2.reset(stream: await db1.replicate());

    expect(db1.replicants.length, 1);
    expect(db2.uid, db1.uid);
    expect(db2.rid, db1.replicants.first.id);
    expect(db2.replicants.length, 1);
    final model2 = db2.get<TestType1>(model1.id);
    expect(model2, isNotNull);
    expect(model1.name, model2.name);

    await db2.close();
    await db2.open();
    expect(db2.uid, db1.uid);
    expect(db2.rid, db1.replicants.first.id);
    expect(db2.replicants.length, 1);
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

    final db = Database('$path/test2.db')..addBuilder<TestType1>((data) => TestType1.fromJson(data));
    await db.reset(socket: await ClientWebSocket.connect(port: 8001));

    expect(await server.dbReplicantCount, 1);
    expect(db.replicants.length, 1);
    expect(db.get<TestType1>(model.id)?.name, model.name);

    await server.destroy();
    await db.destroy();

    expect(await directory.list().toList(), isEmpty);
  });

  test('test bind(1 <-> 2) with pre-existing data', () async {
    final server = await TestIsolate.start(TestServer(path: '$path/test1.db', port: 8001));
    final client = (await ClientWebSocket.connect(port: 8001));

    final db2 = Database('$path/test2.db')..addBuilder<TestType1>((data) => TestType1.fromJson(data));
    await db2.reset(socket: client);

    await server.dbPut(TestType1(id: 'test-id-01', name: 'test01'));
    db2.put(TestType1(id: 'test-id-02', name: 'test02'));

    await db2.bind(client);

    expect(await server.dbModelCount, 2);
    expect(await server.dbModelCount, db2.size);
    expect((await server.dbGet<TestType1>('test-id-01'))?.name, 'test01');
    expect((await server.dbGet<TestType1>('test-id-02'))?.name, 'test02');
    expect(db2.get<TestType1>('test-id-01')?.name, 'test01');
    expect(db2.get<TestType1>('test-id-02')?.name, 'test02');

    await server.destroy();
    await db2.destroy();

    expect(await directory.list().toList(), isEmpty);
  });

  test('test bind(1 <-> 2) fresh', () async {
    final server = await TestIsolate.start(TestServer(path: '$path/test1.db', port: 8001));
    final client = (await ClientWebSocket.connect(port: 8001));

    final db = Database('$path/test2.db')..addBuilder<TestType1>((data) => TestType1.fromJson(data));
    await db.reset(socket: client);

    await db.bind(client);

    await server.dbPut(TestType1(id: 'test-id-01', name: 'test01'));
    expect(await server.dbModelCount, 1);
    expect(db.size, 1);
    expect(db.get('test-id-01'), isNotNull);
    expect(db.get<TestType1>('test-id-01').name, 'test01');

    db.put(TestType1(id: 'test-id-02', name: 'test02'));
    expect(db.size, 2);
    expect(await server.dbModelCount, db.size);
    expect((await server.dbGet<TestType1>('test-id-02'))?.name, 'test02');

    await server.destroy();
    await db.destroy();

    expect(await directory.list().toList(), isEmpty);
  });

  test('test bind(2 <-> 1 <-> 3)', () async {
    final server = await TestIsolate.start(TestServer(path: '$path/test1.db', port: 8001));
    final client1 = (await ClientWebSocket.connect(port: 8001));
    final client2 = (await ClientWebSocket.connect(port: 8001));
    
    final db1 = Database('$path/test2.db')..addBuilder<TestType1>((data) => TestType1.fromJson(data));
    await db1.reset(socket: client1);
    final db2 = Database('$path/test3.db')..addBuilder<TestType1>((data) => TestType1.fromJson(data));
    await db2.reset(socket: client2);

    expect(db1.replicants.length, 1);
    expect(db2.replicants.length, 1);

    await db1.bind(client1);
    await db2.bind(client2);

    expect(await server.dbModelCount, 0);
    expect(db1.size, 0);
    expect(db2.size, 0);

    await server.dbPut(TestType1(id: 'test-id-01', name: 'test01'));
    expect(await server.dbModelCount, 1);
    expect(db1.size, 1);
    expect(db2.size, 1);
    expect((await server.dbGet<TestType1>('test-id-01'))?.name, 'test01');
    expect(db1.get<TestType1>('test-id-01')?.name, 'test01');
    expect(db2.get<TestType1>('test-id-01')?.name, 'test01');

    db1.put(TestType1(id: 'test-id-02', name: 'test02'));
    expect(await server.dbModelCount, 2);
    expect(db1.size, 2);
    expect(db2.size, 2);
    expect((await server.dbGet<TestType1>('test-id-02'))?.name, 'test02');
    expect(db1.get<TestType1>('test-id-02')?.name, 'test02');
    expect(db2.get<TestType1>('test-id-02')?.name, 'test02');

    db2.put(TestType1(id: 'test-id-03', name: 'test03'));
    expect(await server.dbModelCount, 3);
    expect(db1.size, 3);
    expect(db2.size, 3);
    expect((await server.dbGet<TestType1>('test-id-03'))?.name, 'test03');
    expect(db1.get<TestType1>('test-id-03')?.name, 'test03');
    expect(db2.get<TestType1>('test-id-03')?.name, 'test03');

    await server.destroy();
    await db1.destroy();
    await db2.destroy();

    expect(await directory.list().toList(), isEmpty);
  });
}

class TestType1 extends DataModel {
  final String name;
  TestType1({String id, this.name}) : super(id);
  TestType1.fromJson(data) : name = data['name'], super.fromJson(data);
  @override TestType1 copyWith({String id, String name}) => TestType1(id: id ?? this.id, name: name ?? this.name);
  @override Map<String, dynamic> toJson() => super.toJson()..['name'] = name;
}

class TestServer extends TestDatabaseServer {

  TestServer({String path, int port}) : super(path: path, port: port);

  @override
  FutureOr<void> onConfigure(Database db) {
    db.addBuilder<TestType1>((data) => TestType1.fromJson(data));
  }

}
