import 'dart:io';

import 'package:oobium_common/src/data/executor.dart';
import 'package:oobium_common/src/database.dart';

import 'repo_base.dart' as base;

class Repo extends base.Repo {

  final executor = Executor();
  Repo(String db) : super(db);

  String get path => '$db/repo';
  File get file => File(path);

  @override
  Future<Repo> open() async {
    await file.create();
    return this;
  }

  @override
  Future<void> close({bool cancel = false}) {
    return executor.close(cancel: cancel ?? false);
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
}
