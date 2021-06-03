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
    final models = ModelGenTestData('$path/test1.ds');
    await models.open();

    final id = models.put(Message(message: 'test-01')).id;
    await models.close();
    await models.open();

    expect(models.get<Message>(id)?.message, 'test-01');
  });

  test('test nested model', () async {
    final models = ModelGenTestData('$path/test1.ds');
    await models.open();

    final id = models.put(Message(from: User(name: 'joe'), message: 'test-01')).id;
    await models.close();
    await models.open();

    expect(models.get<Message>(id), isNotNull);
    expect(models.get<Message>(id)?.from, isNotNull);
  });

  test('test delete nested model', () async {
    final models = ModelGenTestData('$path/test1.ds');
    await models.open();

    final message = models.put(Message(from: User(name: 'joe'), message: 'test-01'));
    final user = message.from;
    models.remove(message.id);
    await models.close();
    await models.open();

    expect(models.get<Message>(message.id), isNull);
    expect(models.get<User>(user?.id), isNotNull);
  });
}