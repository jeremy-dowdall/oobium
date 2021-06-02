import 'dart:core';

import 'package:oobium/oobium.dart';
import 'package:oobium/src/datastore/data.dart';
import 'package:oobium/src/datastore/models.dart';
import 'package:oobium/src/datastore/sync.dart';
import 'package:oobium/src/datastore.dart';
import 'package:test/test.dart';

Future<void> main() async {

  tearDown(() async => await destroy());

  test('test data create / destroy', () async {
    final data = Data('test-ds');
    await data.open();
    await data.destroy();
    await data.destroy(); // ensure it can be called repeatedly
  });

  test('test data version upgrade', () async {
    final data = Data('test-ds');
    await data.destroy();
    await data.open(onUpgrade: expectAsync1((event) {
      expect(event.oldVersion, 0);
      expect(event.oldData, isNull);
      expect(event.newVersion, 1);
      expect(event.newData, isNotNull);
      return true;
    }, count: 1));
    await data.close();
    await data.open(version: 2, onUpgrade: expectAsync1((event) {
      expect(event.oldVersion, 1);
      expect(event.oldData, isNotNull);
      expect(event.newVersion, 2);
      expect(event.newData, isNotNull);
      return true;
    }, count: 1));
    await data.destroy();
  });

  test('test auto-generate id', () async {
    expect(TestType1(name: 'test01').id, isNotEmpty);
  });

  test('test copyNew creates new id and timestamp', () async {
    final m1 = TestType1(name: 'test01');
    await Future.delayed(Duration(milliseconds: 1));
    final m2 = m1.copyNew();
    expect(m2.id, isNot(m1.id));
    expect(m2.timestamp, isNot(m1.timestamp));
  });

  test('test copyWith maintains id, updates timestamp', () async {
    final m1 = TestType1(name: 'test01');
    await Future.delayed(Duration(milliseconds: 1));
    final m2 = m1.copyWith();
    expect(m2.id, m1.id);
    expect(m2.timestamp, isNot(m1.timestamp));
  });

  test('test fromJson with nested model, context not set', () {
    final m1 = TestType1(name: 'test01');
    final m2 = TestType2.fromJson({'name': 'test02', 'type1': m1.id}, newId: true);
    expect(() => m2.type1, throwsA(isA<Error>()));
  });

  test('test fromJson with nested model, context set', () async {
    final ds = await create().open();
    final m1 = ds.put(TestType1(name: 'test01'));
    final m2 = ds.put(TestType2.fromJson({'name': 'test02', 'type1': m1.id}, newId: true));
    expect(m2.type1, m1);
  });

  test('test toJson with nested model, context set', () async {
    final ds = await create().open();
    final m1 = ds.put(TestType1(name: 'test01'));
    final m2 = ds.put(TestType2.fromJson({'name': 'test02', 'type1': m1.id}, newId: true));
    expect(Json.encode(m2), isNotEmpty);
  });

  // test('test fromJson put nested model, context not set', () async {
  //   final m1 = TestType1(name: 'test01');
  //   final m2 = TestType2.fromJson({'name': 'test02', 'type1': m1}, newId: true);
  //   expect(() => m2.type1, throwsNoSuchMethodError);
  // });

  // test('test fromJson put nested model, context set', () async {
  //   final ds = await create().open();
  //   final m1 = TestType1(name: 'test01');
  //   final m2 = TestType2.fromJson({'name': 'test02', 'type1': m1}, newId: true);
  //   expect(ds.put(m2).type1, m1);
  // });

  test('test data initialization', () async {
    final model = TestType1();
    final ds = await create().open(onUpgrade: (event) {
      return Stream.value(model.toDataRecord());
    });
    expect(ds.size, 1);
    expect(ds.get<TestType1>(model.id)?.isSameAs(model), isTrue);
  });

  test('test DataModel without builders', () async {
    final ds = DataStore('test-data/no-builders');
    await ds.open();
    final model = ds.put(DataModel({'name': 'test 01'}));
    expect(ds.get(model.id), model);

    await ds.close();
    await ds.open();

    expect(ds.get(model.id), isNotNull);
    expect(ds.get(model.id)?.isSameAs(model), isTrue);
    expect(ds.get(model.id), isNot(model));
  });

  test('test custom model without builders', () async {
    final ds = DataStore('test-data/custom-model_no-builders');
    await ds.open();
    final model = ds.put(TestType1(name: 'test 01'));
    expect(ds.get(model.id), model);

    await ds.close();
    await ds.open();

    expect(ds.get(model.id), isNotNull);
    expect(ds.get(model.id)?.isSameAs(model), isFalse); // runtimeType is different
  });

  test('test data event serialization', () {
    final record = DataRecord.fromModel(TestType1(name: 'test-model-01'));
    final event = DataEvent('test-id-01', [record]);
    final json = event.toJson();
    expect(json['history'], ['test-id-01']);
    expect(json['records'], [record.toJsonString()]);

    final restored = DataEvent.fromJson(json);
    expect(restored.history, {'test-id-01'});
    expect(restored.records, isNotEmpty);
    expect(restored.records.first.toJsonString(), record.toJsonString());
  });

  test('test data stored in memory', () async {
    final ds = create();
    await ds.open();
    final model1 = ds.put(TestType1(name: 'test01'));
    final model2 = ds.get<TestType1>(model1.id);
    expect(model2?.name, 'test01');
    expect(model2, model1);
  });

  test('test data stored persistently', () async {
    final ds = create();
    await ds.reset();
    final model = ds.put(TestType1(name: 'test01'));
    await ds.close();

    final ds2 = create(ds);
    await ds2.open();
    expect(ds2.get(model.id), isNotNull);
    expect((ds2.get<TestType1>(model.id))?.name, model.name);
    expect(ds2.get(model.id), isNot(model));
    await ds2.close();
  });

  test('test storing and loading empty model', () async {
    final ds = create();
    await ds.reset();
    final model = ds.put(TestType1());
    await ds.close();

    final ds2 = create(ds);
    await ds2.open();
    expect(ds2.get(model.id), isNotNull);
    expect(ds2.get<TestType1>(model.id), isNotNull);
    expect(ds2.get<TestType1>(model.id)?.name, model.name);
    expect(ds2.get(model.id), isNot(model));
  });

  test('test data copied and persisted', () async {
    final ds = create();
    await ds.reset();
    final m1 = ds.put(TestType1(name: 'test01'));
    ds.put(m1.copyWith(name: 'test02'));
    await ds.close();

    final ds2 = create(ds);
    await ds2.open();
    final data = ds2.getAll<TestType1>().toList();
    expect(data.length, 1);
    expect(data[0].name, 'test02');
  });

  test('test putAll', () async {
    final ds = create();
    await ds.reset();
    ds.putAll([
      TestType1(name: 'test01'),
      TestType1(name: 'test02'),
    ]);
    await ds.close();

    final ds2 = create(ds);
    await ds2.open();
    final models = ds2.getAll().toList();
    expect(models.length, 2);
    expect(models[0].id, isNotEmpty);
    expect(models[1].id, isNotEmpty);
    expect(models[0].id, isNot(models[1].id));
  });

  test('test batch', () async {
    final ds = create();
    await ds.reset();
    final initial = ds.putAll([TestType1(name: 'test01'), TestType1(name: 'test02'),]);
    final results = ds.batch(
      put: [TestType1(name: 'test03'), TestType1(name: 'test04'),],
      remove: [initial[0].id, initial[1].id]
    );
    expect(results.length, 4);
    expect(results[0]?.id, isNotEmpty);
    expect(results[1]?.id, isNotEmpty);
    expect(results[2], initial[0]);
    expect(results[3], initial[1]);
    await ds.close();

    final ds2 = create(ds);
    await ds2.open();
    final models = ds2.getAll().toList();
    expect(models.length, 2);
    expect(models[0].id, isNotEmpty);
    expect(models[1].id, isNotEmpty);
    expect(models[0].id, isNot(models[1].id));
  });

  // test('test compacting', () async {
  //   final ds = create();
  //   for(var i = 0; i < 6; i++) {
  //     ds.put(TestType1(name: 'test-1-$i'));
  //   }
  //   final m = TestType1();
  //   for(var i = 0; i < 6; i++) {
  //     ds.put(m.copyWith(name: 'test-2-$i'));
  //   }
  //   await ds.flush();
  //   final data = await File(ds.path).readAsLines();
  //   expect(data.length, 7);
  //   for(var i = 0; i < 6; i++) {
  //     expect(data[i].name, 'test-1-$i');
  //   }
  //   expect(data[6].name, 'test-2-5');
  // });

  test('test remove', () async {
    final ds = create();
    await ds.reset();
    final model = ds.put(TestType1(name: 'test01'));
    await ds.close();

    final ds2 = create(ds);
    await ds2.open();
    expect(ds2.getAll().length, 1);
    expect(ds2.get(model.id)?.isSameAs(model), isTrue);

    ds2.remove(model.id);
    await ds2.close();

    final ds3 = create();
    await ds3.open();
    expect(ds3.getAll().isEmpty, isTrue);
    expect(ds3.get(model.id), isNull);
  });

  test('test loading a removed model', () async {
    final ds = create();
    await ds.reset();
    final model1 = ds.put(TestType1(name: 'test01'));
    final model2 = ds.put(TestType1(name: 'test02'));
    await ds.close();

    final ds2 = create(ds);
    await ds2.open();
    expect(ds2.getAll().length, 2);
    expect(ds2.get(model1.id)?.isSameAs(model1), isTrue);
    expect(ds2.get(model2.id)?.isSameAs(model2), isTrue);

    ds2.remove(model1.id);
    await ds2.close();

    final ds3 = create(ds);
    await ds3.open();
    expect(ds3.getAll().length, 1);
    expect(ds3.get(model1.id), isNull);
    expect(ds3.get(model2.id)?.isSameAs(model2), isTrue);
  });

  test('test getAll', () async {
    final ds = create();
    await ds.reset();
    ds.put(TestType1(name: 'test-01'));
    ds.put(TestType1(name: 'test-02'));
    ds.put(TestType1(name: 'test-02'));
    expect(ds.getAll<TestType1>().length, 3);
    expect(ds.getAll<TestType1>().where((m) => m.name == 'test-02').length, 2);
    await ds.close();

    final ds2 = create(ds);
    await ds2.open();
    expect(ds2.getAll<TestType1>().length, 3);
    expect(ds2.getAll<TestType1>().where((m) => m.name == 'test-02').length, 2);
  });

  test('test stream', () async {
    final ds = create();
    await ds.reset();
    final model = TestType1(name: 'test-01');
    ds.stream<TestType1>(model.id).listen(expectAsync1<void, TestType1?>((result) {
      expect(result, isNotNull);
      expect(result?.name, 'test-02');
    }, count: 1));
    ds.put(model.copyWith(name: 'test-02'));
  });

  test('test stream removal', () async {
    final ds = create();
    await ds.reset();
    final model = ds.put(TestType1(name: 'test-01'));
    ds.stream<TestType1>(model.id).listen(expectAsync1<void, TestType1?>((result) {
      expect(result, isNull);
    }, count: 1));
    ds.remove(model.id);
  });

  test('test streamAll', () async {
    final ds = create();
    await ds.reset();
    ds.streamAll<TestType1>().listen(expectAsync1<void, DataModelEvent<TestType1>>((results) {
      expect(results.all.length, 3);
    }, count: 1));
    ds.batch(put: [
      TestType1(name: 'test-01'),
      TestType1(name: 'test-02'),
      TestType1(name: 'test-02'),
    ]);
  });

  test('test streamAll removal', () async {
    final ds = create();
    await ds.reset();
    ds.batch(put: [
      TestType1(name: 'test-01'),
      TestType1(name: 'test-02'),
      TestType1(name: 'test-02'),
    ]);
    ds.streamAll<TestType1>().listen(expectAsync1<void, DataModelEvent<TestType1>>((results) {
      expect(results.all.length, 1);
    }, count: 1));
    ds.batch(remove: ds.getAll<TestType1>().where((m) => m.name == 'test-02').map((m) => m.id).toList());
  });

  test('test streamAll skips other types', () async {
    final ds = create();
    await ds.reset();
    ds.streamAll<TestType1>().listen(expectAsync1<void, DataModelEvent<TestType1>>((results) {
      expect(results.all.length, 1);
    }, count: 1));
    ds.put(DataModel({'name': 'test-02'}));
    ds.put(TestType1(name: 'test-02'));
  });

  test('test streamAll accepting types', () async {
    final ds = create();
    await ds.reset();
    ds.streamAll().listen(expectAsync1<void, DataModelEvent>((results) {
      expect(results.all.length, 2);
    }, count: 2));
    ds.put(DataModel({'name': 'test-02'}));
    ds.put(TestType1(name: 'test-02'));
  });

  test('test streamAll with where function', () async {
    final ds = create();
    await ds.reset();
    ds.streamAll<TestType1>(where: (model) => model.name == 'test-02').listen(expectAsync1<void, DataModelEvent>((results) {
      expect(results.all.length, 1);
    }, count: 1));
    ds.put(TestType1(name: 'test-01'));
    ds.put(TestType1(name: 'test-02'));
    ds.put(TestType1(name: 'test-03'));
  });
}

final databases = <DataStore>[];
DataStore create([DataStore? clone]) {
  final path = clone?.path ?? 'test-data/test-${databases.length}';
  final ds = DataStore(path, [(data) => TestType1.fromJson(data)]);
  databases.add(ds);
  return ds;
}
Future<void> reset() => Future.forEach<DataStore>(databases, (ds) => ds.reset()).then((_) => databases.clear());
Future<void> destroy() => Future.forEach<DataStore>(databases, (ds) => ds.destroy()).then((_) => databases.clear());

class TestType1 extends DataModel {
  String? get name => this['name'];
  TestType1({String? name}) : super({'name': name});
  TestType1.copyNew(TestType1 original, {String? name}) : super.copyNew(original, {'name': name});
  TestType1.copyWith(TestType1 original, {String? name}) : super.copyWith(original, {'name': name});
  TestType1.fromJson(data, {bool newId=false}) : super.fromJson(data, {'name'}, {}, newId);
  TestType1 copyNew({String? name}) => TestType1.copyNew(this, name: name);
  TestType1 copyWith({String? name}) => TestType1.copyWith(this, name: name);
}

class TestType2 extends DataModel {
  String? get name => this['name'];
  TestType1? get type1 => this['type1'];
  TestType2({String? name, TestType1? type1}) : super({'name': name});
  TestType2.copyNew(TestType2 original, {String? name, TestType1? type1}) : super.copyNew(original, {'name': name, 'type1': type1});
  TestType2.copyWith(TestType2 original, {String? name, TestType1? type1}) : super.copyWith(original, {'name': name, 'type1': type1});
  TestType2.fromJson(data, {bool newId=false}) : super.fromJson(data, {'name'}, {'type1'}, newId);
  TestType2 copyNew({String? name, TestType1? type1}) => TestType2.copyNew(this, name: name, type1: type1);
  TestType2 copyWith({String? name, TestType1? type1}) => TestType2.copyWith(this, name: name, type1: type1);
}