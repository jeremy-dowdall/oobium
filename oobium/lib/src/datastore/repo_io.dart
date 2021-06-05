import 'dart:io';

import 'package:oobium/src/datastore/data.dart';
import 'package:oobium/src/datastore.dart';

import 'repo_base.dart' as base;

class Repo extends base.Repo {

  Repo(Data data) : super(data);

  late File file;
  int _length = 0;
  int get length => _length;

  @override
  Future<Repo> open() async {
    file = File('${data.connect(this)}/repo');
    await file.create();
    return this;
  }

  @override
  Stream<DataRecord> get([int? timestamp]) async* {
    // TODO timestamp unused
    for(var line in await file.readAsLines()) {
      _length++;
      yield(DataRecord.fromLine(line));
    }
  }

  @override
  Future<void> put(Stream<DataRecord> records) {
    return executor.add(() async {
      final sink = file.openWrite(mode: FileMode.append);
      await for(var record in records) {
        _length++;
        sink.writeln(record);
      }
      await sink.flush();
      await sink.close();
    });
  }

  @override
  Future<void> putAll(Iterable<DataRecord> records) {
    return executor.add(() async {
      final sink = file.openWrite(mode: FileMode.append);
      for(var record in records) {
        _length++;
        sink.writeln(record);
      }
      await sink.flush();
      await sink.close();
    });
  }

  @override
  Future<void> reset(Iterable<DataRecord> records) async {
    return executor.add(() async {
      var count = 0;
      final reset = File('${file.path}.reset');
      final sink = reset.openWrite(mode: FileMode.write);
      for(final record in records) {
        count++;
        sink.writeln(record);
      }
      await sink.flush();
      await sink.close();
      _length = count;
      await reset.rename(file.path);
    });
  }
}
