import 'dart:io';

import 'package:test/test.dart';

import 'model_gen_test.schema.g.dart';

Future<void> main() async {

  final path = 'test-data';
  final directory = Directory(path);
  if(await directory.exists()) {
    await directory.delete(recursive: true);
  }

  setUp(() async => await directory.create(recursive: true));
  tearDown(() async => await directory.delete(recursive: true));

  test('test simple model', () async {
    final models = await ModelGenTestData('$path/test1.ds').open();

    final id = models.put(Message(message: 'test-01')).id;
    await models.close();
    await models.open();

    expect(models.getMessage(id)?.message, 'test-01');
  });

  test('test nested model', () async {
    final models = await ModelGenTestData('$path/test1.ds').open();

    final id = models.put(Message(from: User(name: 'joe'), message: 'test-01')).id;
    await models.close();
    await models.open();

    expect(models.getMessage(id), isNotNull);
    expect(models.getMessage(id)?.from, isNotNull);
  });

  test('test delete nested model', () async {
    final models = await ModelGenTestData('$path/test1.ds').open();

    final message = models.putMessage(from: User(name: 'joe'), message: 'test-01');
    final user = message.from;
    models.remove(message);
    await models.close();
    await models.open();

    expect(models.getMessage(message.id), isNull);
    expect(models.getUser(user?.id), isNotNull);
    expect(models.findUsers(name: 'joe').length, 1);
  });
}