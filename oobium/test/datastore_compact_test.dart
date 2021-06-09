import 'dart:io';

import 'package:test/test.dart';

import 'utils/test_utils.dart';
import 'utils/test_models.dart';

final testFile = 'datastore_compact_test';

void main() {

  setUpAll(() async => await destroyData(testFile));
  // tearDownAll(() async => await destroyData(testFile));

  test('test compacting - local', () async {
    final ds = await createDatastore(testFile).open();
    final file = File('${ds.path}/1/repo');
    final m = TestType1();

    ds.putAll([
      ...List.generate(60000, (i) => TestType1(name: 'test-1-$i')),
      ...List.generate(30000, (i) => m.copyWith(name: 'test-2-$i')),
    ]);
    // for(var j = 0; j < 1000; j++) {
    //   ds.putAll(List.generate(6, (i) => TestType1(name: 'test-1-$j')));
    //   ds.putAll(List.generate(6, (i) => m.copyWith(name: 'test-2-$i')));
    // }
    // ds.compact();
    print('flushing');
    await ds.flush();
    print('flushed');

    final lines = await file.readAsLines();

    expect(ds.size, 60001);
    expect(lines.length, 60001);
    // for(var i = 0; i < 6; i++) {
    //   expect(lines[i], contains('test-1-$i'));
    // }
    // expect(lines[6], contains('test-2-5'));
  });

  test('test compacting - isolate', () async {
    final ds = await createDatastore(testFile).open(isolate: testFile);
    final file = File('${ds.path}/1/repo');
    final m = TestType1();

    ds.putAll([
      ...List.generate(60000, (i) => TestType1(name: 'test-1-$i')),
      ...List.generate(30000, (i) => m.copyWith(name: 'test-2-$i')),
    ]);
    // for(var j = 0; j < 1000; j++) {
    //   ds.putAll(List.generate(6, (i) => TestType1(name: 'test-1-$j')));
    //   ds.putAll(List.generate(6, (i) => m.copyWith(name: 'test-2-$i')));
    // }
    // ds.compact();
    print('flushing');
    await ds.flush();
    print('flushed');

    final lines = await file.readAsLines();

    expect(ds.size, 60001);
    expect(lines.length, 60001);
    // for(var i = 0; i < 6; i++) {
    //   expect(lines[i], contains('test-1-$i'));
    // }
    // expect(lines[6], contains('test-2-5'));
  });
}