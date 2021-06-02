import 'dart:io';

import 'package:oobium/src/datastore/data.dart';
import 'package:oobium/src/datastore.dart';

import 'repo_base.dart' as base;

class Repo extends base.Repo {

  Repo(Data ds) : super(ds);

  late File file;

  @override
  Future<Repo> open() async {
    file = File('${ds.connect(this)}/repo');
    await file.create();
    return this;
  }

  @override
  Stream<DataRecord> get([int? timestamp]) async* {
    // TODO timestamp unused
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
