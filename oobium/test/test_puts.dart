import 'dart:io';

import 'package:oobium/src/datastore.dart';

import 'utils/test_models.dart';

Future<void> main() async {
  final count = 10000;
  print('testPut($count)');
  final start = DateTime.now().millisecondsSinceEpoch;
  final ds = await DataStore('test.ds', builders: [(data) => TestType1.fromJson(data)]);
  await ds.open();
  final open = DateTime.now().millisecondsSinceEpoch;
  final models = ds.getAll<TestType1>().where((m) => m.name == 'test-999').toList();
  print('found ${models.length} models');
  final find = DateTime.now().millisecondsSinceEpoch;
  for(var i = 0; i < count; i++) {
    ds.put(TestType1(name: 'test-$i'));
  }
  final put = DateTime.now().millisecondsSinceEpoch;
  await ds.close();
  final flush = DateTime.now().millisecondsSinceEpoch;
  print('  ${ds.size} records\n  ${(await File(ds.path).stat()).size}bytes\n  time: ${flush-start}ms (open: ${open-start}ms, find: ${find-open}ms, put: ${put-find}ms, flush: ${flush-put}ms)');
}
