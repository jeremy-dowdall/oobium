import 'dart:io';

import 'package:oobium_common/src/data/database.dart';
import 'package:oobium_common_test/oobium_common_test.dart';
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

  test('test invalid provided id', () async {
    expectError(() => TestType1(id: 'test:id', name: 'test01'), 'invalid character ":" in id (pos 4 of "test:id")');
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
    expect(data.length, 1);
  });

  test('test loading data stored on disk', () async {
    final model = TestType1(id: 'test-id', name: 'test01');
    db.put(model);
    await db.flush();
    final db2 = Database(db.path)..addBuilder<TestType1>((data) => TestType1.fromJson(data));
    await db2.open();
    expect(db2.get(model.id), isNotNull);
    expect((db2.get<TestType1>(model.id)).name, model.name);
    expect(db2.get(model.id), isNot(model));
    await db2.close();
  });

  test('test storing and loading empty model', () async {
    final model = TestType1(id: 'test-id');
    db.put(model);
    await db.flush();
    final db2 = Database(db.path)..addBuilder<TestType1>((data) => TestType1.fromJson(data));
    await db2.open();
    expect(db2.get(model.id), isNotNull);
    expect((db2.get<TestType1>(model.id)).name, model.name);
    expect(db2.get(model.id), isNot(model));
    await db2.close();
  });

  test('test data stored on disk is appended', () async {
    db.put(TestType1(id: 'test-id', name: 'test01'));
    db.put(TestType1(id: 'test-id', name: 'test02'));
    await db.flush();
    final data = await File(db.path).readAsLines();
    expect(data.length, 2);
    expect(data[0].contains('test01'), isTrue);
    expect(data[1].contains('test02'), isTrue);
  });

  test('test putAll', () async {
    final models = db.putAll([
      TestType1(name: 'test01'),
      TestType1(name: 'test02'),
    ]);
    await db.flush();
    expect(models.length, 2);
    expect(models[0].id, isNotEmpty);
    expect(models[1].id, isNotEmpty);
    expect(models[0].id, isNot(models[1].id));
    final data = await File(db.path).readAsLines();
    expect(data.length, 2);
    expect(data[0].contains('test01'), isTrue);
    expect(data[1].contains('test02'), isTrue);
  });

  test('test batch', () async {
    final models = db.batch(
      put: [
        TestType1(name: 'test01'),
        TestType1(name: 'test02'),
      ],
      remove: [
        'test-01',
        'test-02'
      ]
    );
    await db.flush();
    expect(models.length, 2);
    expect(models[0].id, isNotEmpty);
    expect(models[1].id, isNotEmpty);
    expect(models[0].id, isNot(models[1].id));
    final data = await File(db.path).readAsLines();
    expect(data.length, 2);
    expect(data[0].contains('test01'), isTrue);
    expect(data[1].contains('test02'), isTrue);
  });

  test('test compacting', () async {
    for(var i = 0; i < 6; i++) {
      db.put(TestType1(name: 'test-1-$i'));
    }
    for(var i = 0; i < 6; i++) {
      db.put(TestType1(id: 'test-id', name: 'test-2-$i'));
    }
    await db.flush();
    final data = await File(db.path).readAsLines();
    expect(data.length, 7);
    for(var i = 0; i < 6; i++) {
      expect(data[i].contains('test-1-$i'), isTrue);
    }
    expect(data[6].contains('test-2-5'), isTrue);
  });

  test('test remove', () async {
    final model = db.put(TestType1(name: 'test01'));
    await db.flush();
    expect(db.size, 1);
    expect(db.get(model.id), model);
    expect((await File(db.path).readAsLines()).length, 1);

    db.remove(model.id);
    await db.flush();
    expect(db.size, 0);
    expect(db.get(model.id), isNull);
    expect((await File(db.path).readAsLines()).length, 2);

    await db.compact();
    await db.flush();
    expect(db.size, 0);
    expect(db.get(model.id), isNull);
    expect((await File(db.path).readAsLines()).length, 0);
  });

  test('test loading a removed model', () async {
    final model1 = db.put(TestType1(name: 'test01'));
    final model2 = db.put(TestType1(name: 'test02'));
    await db.flush();
    expect(db.size, 2);
    expect(db.get(model1.id), model1);
    expect(db.get(model2.id), model2);
    expect((await File(db.path).readAsLines()).length, 2);

    db.remove(model1.id);
    await db.flush();
    expect(db.size, 1);
    expect(db.get(model1.id), isNull);
    expect(db.get(model2.id), model2);
    expect((await File(db.path).readAsLines()).length, 3);

    final db2 = Database(db.path);
    db2.addBuilder<TestType1>((data) => TestType1.fromJson(data));
    await db2.open();
    expect(db2.size, 1);
    expect(db2.get(model1.id), isNull);
    expect(db2.get(model2.id), isNot(model2));
    expect(db2.get(model2.id), isNotNull);
    expect(db2.get<TestType1>(model2.id).name, model2.name);
    expect((await File(db2.path).readAsLines()).length, 3);
    await db2.close();
  });

  test('test getAll', () async {
    db.put(TestType1(name: 'test-01'));
    final model = db.put(TestType1(name: 'test-02'));
    db.put(TestType1(name: 'test-02'));

    expect(db.getAll<TestType1>().length, 3);
    expect(db.getAll<TestType1>().where((m) => m.name == 'test-02').length, 2);
    expect(db.getAll<TestType1>().firstWhere((m) => m.name == 'test-02'), model);
  });
}

class TestType1 extends DataModel {
  final String name;
  TestType1({String id, this.name}) : super(id);
  TestType1.fromJson(data) : name = data['name'], super.fromJson(data);
  @override TestType1 copyWith({String id, String name}) => TestType1(id: id ?? this.id, name: name ?? this.name);
  @override Map<String, dynamic> toJson() => super.toJson()..['name'] = name;
}