import 'dart:io';

import 'package:oobium_common/src/database/database.dart';
import 'package:oobium_common/src/json.dart';
import 'package:test/test.dart';

Future<void> main() async {
  final db = await Database('test.db')..addBuilder<TestType1>((data) => TestType1.fromJson(data));
  await db.open();

  setUp(() async => await db.reset());
  tearDownAll(() async => await db.destroy());

  test('test auto-generate id', () async {
    final input = TestType1(name: 'test01');
    final output = db.put(input);
    expect(output.id, isNotEmpty);
    expect(output.name, 'test01');
    expect(output, isNot(input));
  });

  test('test provided id', () async {
    final input = TestType1(id: 'test-id', name: 'test01');
    final output = db.put(input);
    expect(output.id, isNotEmpty);
    expect(output.name, 'test01');
    expect(output, input);
  });

  test('test data stored in memory', () async {
    final input = TestType1(id: 'test-id', name: 'test01');
    db.put(input);
    final output = db.get<TestType1>('test-id');
    expect(output.id, isNotEmpty);
    expect(output.name, 'test01');
    expect(output, input);
  });

  test('test data stored on disk', () async {
    final input = TestType1(id: 'test-id', name: 'test01');
    db.put(input);
    await db.flush();
    final data = await File(db.path).readAsLines();
    print('data: $data');
    expect(data.length, 1);
  });

  test('test loading data stored on disk', () async {
    await db.reset();
    final input = TestType1(id: 'test-id', name: 'test01');
    db.put(TestType1(id: 'test-id', name: 'test01'));
    db.put(input);
    await db.flush();
    final db2 = Database('test.db')..addBuilder<TestType1>((data) => TestType1.fromJson(data));
    await db2.open();
    final data = db2.get<TestType1>(input.id);
    await db2.close();
    expect(data, isNotNull);
    expect(data.id, input.id);
    expect(data.name, input.name);
    expect(data, isNot(input));
  });

  test('test data stored on disk is appended', () async {
    db.put(TestType1(id: 'test-id', name: 'test01'));
    db.put(TestType1(id: 'test-id', name: 'test02'));
    await db.flush();
    final data = await File(db.path).readAsLines();
    print('data: $data');
    expect(data.length, 2);
    expect(data[0].contains('test01'), isTrue);
    expect(data[1].contains('test02'), isTrue);
  });

  test('test compaction', () async {
    db.put(TestType1(name: 'test01'));
    print('records: ${db.size}, obsolete: ${db.percentObsolete}%');
    db.put(TestType1(name: 'test01'));
    print('records: ${db.size}, obsolete: ${db.percentObsolete}%');
    db.put(TestType1(name: 'test01'));
    print('records: ${db.size}, obsolete: ${db.percentObsolete}%');
    db.put(TestType1(name: 'test01'));
    print('records: ${db.size}, obsolete: ${db.percentObsolete}%');
    db.put(TestType1(name: 'test01'));
    print('records: ${db.size}, obsolete: ${db.percentObsolete}%');
    db.put(TestType1(name: 'test01'));
    print('records: ${db.size}, obsolete: ${db.percentObsolete}%');
    db.put(TestType1(id: 'test-id', name: 'test01'));
    print('records: ${db.size}, obsolete: ${db.percentObsolete}%');
    db.put(TestType1(id: 'test-id', name: 'test01'));
    print('records: ${db.size}, obsolete: ${db.percentObsolete}%');
    db.put(TestType1(id: 'test-id', name: 'test01'));
    print('records: ${db.size}, obsolete: ${db.percentObsolete}%');
    db.put(TestType1(id: 'test-id', name: 'test01'));
    print('records: ${db.size}, obsolete: ${db.percentObsolete}%');
    db.put(TestType1(id: 'test-id', name: 'test01'));
    print('records: ${db.size}, obsolete: ${db.percentObsolete}%');
    db.put(TestType1(id: 'test-id', name: 'test01'));
    print('records: ${db.size}, obsolete: ${db.percentObsolete}%');
    await db.flush();
    final data = await File(db.path).readAsLines();
    print('data: $data');
    expect(data, isNotEmpty);
  });
}

class TestType1 extends JsonModel {
  final String name;
  TestType1({String id, this.name}) : super(id);
  TestType1.fromJson(data) : name = Json.field(data, 'name'), super.fromJson(data);
  @override Map<String, dynamic> toJson() => super.toJson()..['name'] = name;
}