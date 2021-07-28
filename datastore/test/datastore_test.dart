import 'dart:core';

import 'package:objectid/objectid.dart';
import 'package:oobium_datastore/oobium_datastore.dart';
import 'package:oobium_datastore/src/datastore/data.dart';
import 'package:oobium_datastore/src/datastore/models.dart';
import 'package:oobium_datastore/src/datastore.dart';
import 'package:test/test.dart';

import 'utils/test_utils.dart';

final testFile = 'datastore_test';

Future<void> main() async {

  setUpAll(() async => await destroyData(testFile));
  tearDownAll(() async => await destroyData(testFile));

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

  test('test auto-generate modelId and updateId', () {
    final model = TestType1(name: 'test01');
    expect(model['_modelId'], isA<ObjectId>());
    expect(model['_updateId'], isA<ObjectId>());
    expect(model['_modelId'], isNot(model['_updateId']));
  });

  test('test copyNew creates new modelId and updateId', () {
    final m1 = TestType1(name: 'test01');
    final m2 = m1.copyNew();
    expect(m2['_modelId'], isNot(m1['_modelId']));
    expect(m2['_updateId'], isNot(m1['_updateId']));
  });

  test('test copyWith maintains modelId, creates new updateId', () {
    final m1 = TestType1(name: 'test01');
    final m2 = m1.copyWith();
    expect(m1['_modelId'], m2['_modelId']);
    expect(m1['_updateId'], isNot(m2['_updateId']));
  });

  test('test custom model without adapter', () async {
    final ds = await DataStore('test-data/custom-model_no-adapter',
      adapters: Adapters([])
    ).open();
    expect(() => ds.put(TestType1(name: 'test 01')), throwsA(isA<Error>()));
  });

  test('test data stored in memory', () async {
    final ds = createDatastore(testFile);
    await ds.open();
    final model1 = ds.put(TestType1(name: 'test01'));
    final model2 = ds.get<TestType1>(model1.id);
    expect(model2?.name, 'test01');
    expect(model2, model1);
  });

  test('test data stored persistently', () async {
    final ds = createDatastore(testFile);
    await ds.reset();
    final model = ds.put(TestType1(name: 'test01'));
    await ds.close();

    final ds2 = createDatastore(testFile, clone: ds);
    await ds2.open();
    expect(ds2.get(model.id), isNotNull);
    expect((ds2.get<TestType1>(model.id))?.name, model.name);
    expect(identical(ds2.get(model.id), model), isFalse);
    await ds2.close();
  });

  test('test storing and loading empty model', () async {
    final ds = createDatastore(testFile);
    await ds.reset();
    final model = ds.put(TestType1());
    await ds.close();

    final ds2 = createDatastore(testFile, clone: ds);
    await ds2.open();
    expect(ds2.get(model.id), isNotNull);
    expect(ds2.get<TestType1>(model.id), isNotNull);
    expect(ds2.get<TestType1>(model.id)?.name, model.name);
    expect(identical(ds2.get(model.id), model), isFalse);
  });

  test('test data copied and persisted', () async {
    final ds = createDatastore(testFile);
    await ds.reset();
    final m1 = ds.put(TestType1(name: 'test01'));
    ds.put(m1.copyWith(name: 'test02'));
    await ds.close();

    final ds2 = createDatastore(testFile, clone: ds);
    await ds2.open();
    final data = ds2.getAll<TestType1>().toList();
    expect(data.length, 1);
    expect(data[0].name, 'test02');
  });

  test('test putAll', () async {
    final ds = createDatastore(testFile);
    await ds.reset();
    ds.putAll([
      TestType1(name: 'test01'),
      TestType1(name: 'test02'),
    ]);
    await ds.close();

    final ds2 = createDatastore(testFile, clone: ds);
    await ds2.open();
    final models = ds2.getAll().toList();
    expect(models.length, 2);
    expect(models[0]['_modelId'], isA<ObjectId>());
    expect(models[1]['_modelId'], isA<ObjectId>());
    expect(models[0]['_modelId'], isNot(models[1]['_modelId']));
  });

  test('test batch', () async {
    final ds = createDatastore(testFile);
    await ds.reset();
    final initial = ds.putAll([TestType1(name: 'test01'), TestType1(name: 'test02'),]);
    final results = ds.batch(
      put: [TestType1(name: 'test03'), TestType1(name: 'test04'),],
      remove: [initial[0], initial[1]]
    );
    expect(results.length, 4);
    expect(results[0].id, isA<ObjectId>());
    expect(results[1].id, isA<ObjectId>());
    expect(results[2], initial[0]);
    expect(results[3], initial[1]);
    expect(ds.size, 2);
    await ds.close();

    final ds2 = createDatastore(testFile, clone: ds);
    await ds2.open();
    final models = ds2.getAll().toList();
    expect(models.length, 2);
    expect(models[0]['_modelId'], isA<ObjectId>());
    expect(models[1]['_modelId'], isA<ObjectId>());
    expect(models[0]['_modelId'], isNot(models[1]['_modelId']));
  });

  test('test remove', () async {
    final ds = createDatastore(testFile);
    await ds.reset();
    final model = ds.put(TestType1(name: 'test01'));
    await ds.close();

    final ds2 = createDatastore(testFile, clone: ds);
    await ds2.open();
    expect(ds2.getAll().length, 1);
    expect(ds2.get(model.id)?.isSameAs(model), isTrue);

    ds2.remove(model);
    await ds2.close();

    final ds3 = createDatastore(testFile);
    await ds3.open();
    expect(ds3.getAll().isEmpty, isTrue);
    expect(ds3.get(model.id), isNull);
  });

  test('test loading a removed model', () async {
    final ds = createDatastore(testFile);
    await ds.reset();
    final model1 = ds.put(TestType1(name: 'test01'));
    final model2 = ds.put(TestType1(name: 'test02'));
    await ds.close();

    final ds2 = createDatastore(testFile, clone: ds);
    await ds2.open();
    expect(ds2.getAll().length, 2);
    expect(ds2.get(model1.id)?.isSameAs(model1), isTrue);
    expect(ds2.get(model2.id)?.isSameAs(model2), isTrue);

    ds2.remove(model1);
    await ds2.close();

    final ds3 = createDatastore(testFile, clone: ds);
    await ds3.open();
    expect(ds3.getAll().length, 1);
    expect(ds3.get(model1.id), isNull);
    expect(ds3.get(model2.id)?.isSameAs(model2), isTrue);
  });

  test('test getAll', () async {
    final ds = createDatastore(testFile);
    await ds.reset();
    ds.put(TestType1(name: 'test-01'));
    ds.put(TestType1(name: 'test-02'));
    ds.put(TestType1(name: 'test-02'));
    expect(ds.getAll<TestType1>().length, 3);
    expect(ds.getAll<TestType1>().where((m) => m.name == 'test-02').length, 2);
    await ds.close();

    final ds2 = createDatastore(testFile, clone: ds);
    await ds2.open();
    expect(ds2.getAll<TestType1>().length, 3);
    expect(ds2.getAll<TestType1>().where((m) => m.name == 'test-02').length, 2);
  });

  test('test stream', () async {
    final ds = createDatastore(testFile);
    await ds.reset();
    final model = TestType1(name: 'test-01');
    ds.stream<TestType1>(model.id).listen(expectAsync1<void, TestType1?>((result) {
      expect(result, isNotNull);
      expect(result?.name, 'test-02');
    }, count: 1));
    ds.put(model.copyWith(name: 'test-02'));
  });

  test('test stream removal', () async {
    final ds = createDatastore(testFile);
    await ds.reset();
    final model = ds.put(TestType1(name: 'test-01'));
    ds.stream<TestType1>(model.id).listen(expectAsync1<void, TestType1?>((result) {
      expect(result, isNull);
    }, count: 1));
    ds.remove(model);
  });

  test('test streamAll', () async {
    final ds = createDatastore(testFile);
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
    final ds = createDatastore(testFile);
    await ds.reset();
    ds.batch(put: [
      TestType1(name: 'test-01'),
      TestType1(name: 'test-02'),
      TestType1(name: 'test-02'),
    ]);
    ds.streamAll<TestType1>().listen(expectAsync1<void, DataModelEvent<TestType1>>((results) {
      expect(results.all.length, 1);
    }, count: 1));
    ds.batch(remove: ds.getAll<TestType1>().where((m) => m.name == 'test-02').toList());
  });

  test('test streamAll skips other types', () async {
    final ds = createDatastore(testFile);
    await ds.reset();
    ds.streamAll<TestType1>().listen(expectAsync1<void, DataModelEvent<TestType1>>((results) {
      expect(results.all.length, 1);
    }, count: 1));
    ds.put(TestType2(name: 'test-02'));
    ds.put(TestType1(name: 'test-01'));
  });

  test('test streamAll accepting types', () async {
    final ds = createDatastore(testFile);
    await ds.reset();
    ds.streamAll().listen(expectAsync1<void, DataModelEvent>((results) {
      expect(results.all.length, 2);
    }, count: 2));
    ds.put(TestType2(name: 'test-02'));
    ds.put(TestType1(name: 'test-01'));
  });

  test('test streamAll with where function', () async {
    final ds = createDatastore(testFile);
    await ds.reset();
    ds.streamAll<TestType1>(where: (model) => model.name == 'test-02').listen(expectAsync1<void, DataModelEvent>((results) {
      expect(results.all.length, 1);
    }, count: 1));
    ds.put(TestType1(name: 'test-01'));
    ds.put(TestType1(name: 'test-02'));
    ds.put(TestType1(name: 'test-03'));
  });

  test('test indexes', () async {
    final ds = DataStore('test-data/test-${datastores.length}',
      adapters: Adapters([]),
      indexes: [DataIndex<TestType1>(toKey: (model) => model.name)]
    );
    await ds.reset();
    final model = ds.put(TestType1(name: 'test-with-index'));
    expect(ds.get<TestType1>('test-with-index')?.id, model.id);
  });
}
