import 'dart:io';

import 'package:oobium/src/data/data.dart';
import 'package:oobium/src/database.dart';

import 'repo_base.dart' as base;

class Repo extends base.Repo {

  Repo(Data db) : super(db);

  File file;

  @override
  Future<Repo> open() async {
    file = File('${db.connect(this)}/repo');
    await file.create();
    return this;
  }

  @override
  Stream<DataRecord> get([int timestamp]) async* {
    for(var line in await file.readAsLines()) {
      yield(DataRecord.fromLine(line));
    }
  }

  @override
  Future<void> put(Stream<DataRecord> records) {
    // TODO compact
    return executor.add(() async {
      final sink = file.openWrite(mode: FileMode.append);
      await for(var record in records) {
        sink.writeln(record);
      }
      await sink.flush();
      await sink.close();
    });
  }

  @override
  Future<void> putAll(Iterable<DataRecord> records) {
    // TODO compact
    return executor.add(() async {
      final sink = file.openWrite(mode: FileMode.append);
      for(var record in records) {
        sink.writeln(record);
      }
      await sink.flush();
      await sink.close();
    });
  }
}
