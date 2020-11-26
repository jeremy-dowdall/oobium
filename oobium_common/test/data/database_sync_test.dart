import 'package:oobium_common/src/data/database.dart';
import 'package:test/test.dart';

Future<void> main() async {
  test('test replication', () async {
    final db1 = Database('test1.db')..addBuilder<TestType1>((data) => TestType1.fromJson(data));
    await db1.reset(uid: db1.newId());
    expect(db1.uid, isNotNull);
    expect(db1.rid, isNotNull);

    final db2 = Database('test2.db')..addBuilder<TestType1>((data) => TestType1.fromJson(data));
    await db2.reset();
    expect(db2.uid, isNull);
    expect(db2.rid, isNull);

    final model1 = db1.put(TestType1(name: 'test01'));
    expect(db1.size, 1);

    final stream = await db1.replicate();
    expect(db1.replicants, isEmpty);

    await db2.reset(stream: stream);
    expect(db1.replicants.length, 1);
    expect(db2.uid, db1.uid);
    expect(db2.rid, db1.replicants.first);
    expect(db2.replicants, isEmpty);
    final model2 = db2.get<TestType1>(model1.id);
    expect(model2, isNotNull);
    expect(model1.name, model2.name);

    await db2.close();
    await db2.open();
    expect(db2.uid, db1.uid);
    expect(db2.rid, db1.replicants.first);
    expect(db2.replicants, isEmpty);
    final model3 = db2.get<TestType1>(model1.id);
    expect(model3, isNotNull);
    expect(model1.name, model2.name);

    await db1.destroy();
    await db2.destroy();
  });

  test('test sync(1 <-> 2)', () async {
    final db1 = Database('test1.db')..addBuilder<TestType1>((data) => TestType1.fromJson(data));
    await db1.reset(uid: db1.newId());
    // db1.createSocket(ws1);
    final db2 = Database('test2.db')..addBuilder<TestType1>((data) => TestType1.fromJson(data));
    await db2.reset(stream: await db1.replicate());
    // db2.createSocket(ws2);

    db1.put(TestType1(id: 'test-id-01', name: 'test01'));
    db2.put(TestType1(id: 'test-id-02', name: 'test02'));


    print('bind start');
    // server.on.get('/sync', [websocket((socket) async {
      await db1.bind(socket);
    // })]);
    print('bind end');

    expect(db1.size, 2);
    expect(db1.size, db2.size);
    expect(db1.get<TestType1>('test-id-01')?.name, 'test01');
    expect(db1.get<TestType1>('test-id-02')?.name, 'test02');
    expect(db2.get<TestType1>('test-id-01')?.name, 'test01');
    expect(db2.get<TestType1>('test-id-02')?.name, 'test02');

    await db1.destroy();
    await db2.destroy();
  });

  test('test bind(1 <-> 2)', () async {
    final db1 = Database('test1.db')..addBuilder<TestType1>((data) => TestType1.fromJson(data));
    await db1.reset(uid: db1.newId());
    final db2 = Database('test2.db')..addBuilder<TestType1>((data) => TestType1.fromJson(data));
    await db2.reset(stream: await db1.replicate());

    db1.bind(db2.socket);

    db1.put(TestType1(id: 'test-id-01', name: 'test01'));
    expect(db1.size, 1);
    expect(db2.size, db1.size);
    expect(db2.get('test-id-01'), isNotNull);
    expect(db2.get<TestType1>('test-id-01').name, 'test01');

    db2.put(TestType1(id: 'test-id-02', name: 'test02'));
    expect(db2.size, 2);
    expect(db1.size, db2.size);
    expect(db1.get('test-id-02'), isNotNull);
    expect(db1.get<TestType1>('test-id-02').name, 'test02');

    await db1.destroy();
    await db2.destroy();
  });

  test('test bind(1 <-> 2 & 3)', () async {
    final db1 = Database('test1.db')..addBuilder<TestType1>((data) => TestType1.fromJson(data));
    await db1.reset(uid: db1.newId());
    final db2 = Database('test2.db')..addBuilder<TestType1>((data) => TestType1.fromJson(data));
    await db2.reset(stream: await db1.replicate());
    final db3 = Database('test2.db')..addBuilder<TestType1>((data) => TestType1.fromJson(data));
    await db3.reset(stream: await db1.replicate());

    db1.bind(db2.socket);
    db1.bind(db3.socket);

    db1.put(TestType1(id: 'test-id-01', name: 'test01'));
    expect(db1.size, 1);
    expect(db2.size, db1.size);
    expect(db2.get<TestType1>('test-id-01')?.name, 'test01');
    expect(db3.size, db1.size);
    expect(db3.get<TestType1>('test-id-01')?.name, 'test01');

    db2.put(TestType1(id: 'test-id-02', name: 'test02'));
    expect(db2.size, 2);
    expect(db1.size, db2.size);
    expect(db1.get<TestType1>('test-id-02')?.name, 'test02');
    expect(db3.size, db2.size);
    expect(db3.get<TestType1>('test-id-02')?.name, 'test02');

    db3.put(TestType1(id: 'test-id-03', name: 'test03'));
    expect(db3.size, 3);
    expect(db1.size, db3.size);
    expect(db1.get<TestType1>('test-id-02')?.name, 'test02');
    expect(db2.size, db3.size);
    expect(db2.get<TestType1>('test-id-02')?.name, 'test02');

    await db1.destroy();
    await db2.destroy();
    await db3.destroy();
  });

  test('test bind(1 <-> 2 <-> 3)', () async {
    final db1 = Database('test1.db')..addBuilder<TestType1>((data) => TestType1.fromJson(data));
    await db1.reset(uid: db1.newId());
    final db2 = Database('test2.db')..addBuilder<TestType1>((data) => TestType1.fromJson(data));
    await db2.reset(stream: await db1.replicate());
    final db3 = Database('test2.db')..addBuilder<TestType1>((data) => TestType1.fromJson(data));
    await db3.reset(stream: await db1.replicate());

    db1.bind(db2.socket);
    db2.bind(db3.socket);

    db1.put(TestType1(id: 'test-id-01', name: 'test01'));
    expect(db1.size, 1);
    expect(db2.size, db1.size);
    expect(db2.get<TestType1>('test-id-01')?.name, 'test01');
    expect(db3.size, db1.size);
    expect(db3.get<TestType1>('test-id-01')?.name, 'test01');

    db2.put(TestType1(id: 'test-id-02', name: 'test02'));
    expect(db2.size, 2);
    expect(db1.size, db2.size);
    expect(db1.get<TestType1>('test-id-02')?.name, 'test02');
    expect(db3.size, db2.size);
    expect(db3.get<TestType1>('test-id-02')?.name, 'test02');

    db3.put(TestType1(id: 'test-id-03', name: 'test03'));
    expect(db3.size, 3);
    expect(db1.size, db3.size);
    expect(db1.get<TestType1>('test-id-02')?.name, 'test02');
    expect(db2.size, db3.size);
    expect(db2.get<TestType1>('test-id-02')?.name, 'test02');

    await db1.destroy();
    await db2.destroy();
    await db3.destroy();
  });
}

class TestType1 extends DataModel {
  final String name;
  TestType1({String id, this.name}) : super(id);
  TestType1.fromJson(data) : name = data['name'], super.fromJson(data);
  @override TestType1 copyWith({String id, String name}) => TestType1(id: id ?? this.id, name: name ?? this.name);
  @override Map<String, dynamic> toJson() => super.toJson()..['name'] = name;
}
