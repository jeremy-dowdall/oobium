import 'dart:io';

import 'package:oobium/src/datastore/models.dart';
import 'package:test/test.dart';

import 'utils/test_utils.dart';
import 'utils/test_models.dart';

final testFile = 'repo_compact_test';

void main() {

  setUpAll(() async => await destroy(testFile));
  tearDownAll(() async => await destroy(testFile));

  test('test compact', () async {
    final data = await createData(testFile).open();
    final repo = await createRepo(data).open();
    final models = await Models([],[]);
    final file = File((repo as dynamic).file.path);
    final m = TestType1();

    final puts = models.batch(put: [
      ...List.generate(6, (i) => TestType1(name: 'test-1-$i')),
      ...List.generate(6, (i) => m.copyWith(name: 'test-2-$i'))
    ]).puts;
    expect(models.length, 7);

    repo.putAll(puts.map((m) => m.toDataRecord()));
    await repo.flush();
    expect(repo.length, 12);
    expect((await file.readAsLines()).length, 12);

    print('reset start (${models.getAll().length})');
    await repo.reset(models.getAll().map((m) => m.toDataRecord()));
    print('reset done');

    final lines = await file.readAsLines();
    expect(lines.length, 7);
    for(var i = 0; i < 6; i++) {
      expect(lines[i], contains('test-1-$i'));
    }
    expect(lines[6], contains('test-2-5'));
  });

}