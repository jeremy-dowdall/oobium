import 'dart:indexed_db';

import 'package:oobium_common/src/data/data.dart';
import 'package:oobium_common/src/database.dart' show DataRecord;

import 'repo_base.dart' as base;

class Repo extends base.Repo {

  Repo(Data db) : super(db);

  Database idb;

  @override
  Future<Repo> open() async {
    idb = db.connect(this);
    return this;
  }

  @override
  Stream<DataRecord> get([int timestamp]) {
    return idb.transaction('repo', 'readonly').objectStore('repo').openCursor(autoAdvance: true).map((event) {
      return DataRecord.fromLine(event.value);
    });
  }

  @override
  Future<void> put(Stream<DataRecord> records) {
    return executor.add(() async {
      final tx = idb.transaction('repo', 'readwrite').objectStore('repo');
      await for(var record in records) {
        if(record.isDelete) {
          await tx.delete(record.id);
        } else {
          await tx.put(record.toString(), record.id);
        }
      }
    });
  }

  @override
  Future<void> putAll(Iterable<DataRecord> records) {
    return executor.add(() async {
      final tx = idb.transaction('repo', 'readwrite').objectStore('repo');
      for(var record in records) {
        if(record.isDelete) {
          await tx.delete(record.id);
        } else {
          await tx.put(record.toString(), record.id);
        }
      }
    });
  }
}
