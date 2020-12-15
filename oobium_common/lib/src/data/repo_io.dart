import 'dart:io';

import 'package:oobium_common/src/data/executor.dart';
import 'package:oobium_common/src/database.dart';

import 'repo_base.dart' as base;

class Repo extends base.Repo {

  final File repo;
  final executor = Executor();
  Repo(String path) : repo = File('$path.repo'), super(path);

  Future<void> open() {
    return repo.create(recursive: true);
  }

  Future<void> close() async {
    return executor.close();
  }

  Future<void> destroy() async {
    await executor.close(cancel: true);
    if(await repo.exists()) {
      return repo.delete();
    } else {
      return Future.value();
    }
  }

  Stream<DataRecord> read() async* {
    for(var line in await repo.readAsLines()) {
      yield(DataRecord.fromLine(line));
    }
  }

  void write(Iterable<DataRecord> records) {
    executor.add(() async {
      final sink = repo.openWrite(mode: FileMode.append);
      for(var record in records) {
        sink.writeln(record);
      }
      await sink.flush();
      await sink.close();
    });
  }

  Future<void> writeStream(Stream<String> lines) {
    return executor.add(() async {
      final sink = repo.openWrite();
      await for(var line in lines) {
        sink.writeln(line);
      }
      await sink.flush();
      await sink.close();
    });
  }
}
