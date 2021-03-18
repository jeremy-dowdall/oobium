import 'dart:convert';
import 'dart:io';

import 'package:objectid/objectid.dart';
import 'package:test/test.dart';

Future<void> main() async {

  if(await Directory('test-data').exists()) {
    await Directory('test-data').delete(recursive: true);
  }
  await Directory('test-data').create(recursive: true);

  test('test something', () async {
    final records = <Record>[];
    for(var i = 0; i < 10; i++) {
      final data = {'uid':ObjectId().hexString, 'token': ObjectId().hexString, 'name': 'joe bob'};
      final record = Record(records.isEmpty ? 0 : records.last.end, data);
      records.add(record);
      await record.save();
    }

    final positions = (await File('test-data/meta').readAsLines()).fold<Map<String, List<int>>>({}, (a, l) {
      final id = l.split(':')[0];
      final pos = l.split(':')[1].split('-');
      a[id] = [int.parse(pos[0]), int.parse(pos[1])];
      return a;
    });

    for(var i = 0; i < 10; i++) {
      final record = records[i];
      final position = positions[record.id];
      final data = await read(position);
      print(data);
      expect(data, record.data);
    }
  });
}

Future<String> read(List<int> position) async {
  final reader = await File('test-data/data').open(mode: FileMode.read);
  await reader.setPosition(position[0]);
  final data = utf8.decode(await reader.read(position[1]));
  await reader.close();
  return data;
}

class Record {
  String id;
  String meta;
  String data;
  int end;
  Record(int position, data) {
    this.id = ObjectId().hexString;
    this.data = jsonEncode(data);
    this.end = position + this.data.length;
    this.meta = '$id:$position-${this.data.length}';
  }

  Future<void> save() async {
    await File('test-data/meta').writeAsString('$meta\n', mode: FileMode.append, flush: true);
    await File('test-data/data').writeAsString(data, mode: FileMode.append, flush: true);
  }
}