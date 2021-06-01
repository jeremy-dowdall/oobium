import 'dart:io';

import 'package:oobium/src/database.dart';

Future<void> main() async {
  final count = 10000;
  print('testPut($count)');
  final start = DateTime.now().millisecondsSinceEpoch;
  final db = await Database('test.db', [(data) => TestType1.fromJson(data)]);
  await db.open();
  final open = DateTime.now().millisecondsSinceEpoch;
  final models = db.getAll<TestType1>().where((m) => m.name == 'test-999').toList();
  print('found ${models.length} models');
  final find = DateTime.now().millisecondsSinceEpoch;
  for(var i = 0; i < count; i++) {
    db.put(TestType1(name: 'test-$i'));
  }
  final put = DateTime.now().millisecondsSinceEpoch;
  await db.close();
  final flush = DateTime.now().millisecondsSinceEpoch;
  print('  ${db.size} records\n  ${(await File(db.path).stat()).size}bytes\n  time: ${flush-start}ms (open: ${open-start}ms, find: ${find-open}ms, put: ${put-find}ms, flush: ${flush-put}ms)');
}

class TestType1 extends DataModel {
  String get name => this['name'];
  TestType1({required String name}) : super({'name': name});
  TestType1.copyNew(TestType1 original, {required String name}) : super.copyNew(original, {'name': name});
  TestType1.copyWith(TestType1 original, {required String name}) : super.copyWith(original, {'name': name});
  TestType1.fromJson(data, {bool newId=false}) : super.fromJson(data, {'name'}, {}, newId);
  TestType1 copyNew({required String name}) => TestType1.copyNew(this, name: name);
  TestType1 copyWith({required String name}) => TestType1.copyWith(this, name: name);
}
