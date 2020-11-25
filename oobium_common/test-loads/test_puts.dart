import 'dart:io';

import 'package:oobium_common/src/data/database.dart';

Future<void> main() async {
  final count = 10000;
  print('testPut($count)');
  final start = DateTime.now().millisecondsSinceEpoch;
  final db = await Database('test.db')..addBuilder<TestType1>((data) => TestType1.fromJson(data));
  await db.open();
  final open = DateTime.now().millisecondsSinceEpoch;
  final models = db.getAll<TestType1>().where((m) => m.name == 'test-999').toList();
  print('found ${models.length} models');
  final read = DateTime.now().millisecondsSinceEpoch;
  for(var i = 0; i < count; i++) {
    db.put(TestType1(name: 'test-$i'));
  }
  final put = DateTime.now().millisecondsSinceEpoch;
  await db.flush();
  final flush = DateTime.now().millisecondsSinceEpoch;
  print('  ${db.size} records\n  ${(await File(db.path).stat()).size}bytes\n  time: ${flush-start}ms (open: ${open-start}ms, read: ${read-open}ms, put: ${put-read}ms, flush: ${flush-put}ms)');
}

class TestType1 extends DataModel {
  final String name;
  TestType1({String id, this.name}) : super(id);
  TestType1.fromJson(data) : name = data['name'], super.fromJson(data);
  @override TestType1 copyWith({String id, String name}) => TestType1(id: id ?? this.id, name: name ?? this.name);
  @override Map<String, dynamic> toJson() => super.toJson()..['name'] = name;
}