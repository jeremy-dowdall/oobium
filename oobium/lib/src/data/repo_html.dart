import 'dart:indexed_db';

import 'package:oobium/src/data/data.dart';
import 'package:oobium/src/database.dart' show DataRecord;

import 'repo_base.dart' as base;

class Repo extends base.Repo {

  Repo(Data db) : super(db);

  Database idb;

  @override
  Future<Repo> open() {
    idb = db.connect(this);
    return Future.value(this);
  }

  @override
  Stream<DataRecord> get([int timestamp]) {
    // TODO timestamp unused
    return idb.transaction('repo', 'readonly').objectStore('repo').openCursor(autoAdvance: true).map((event) {
      return DataRecord.fromLine(event.value);
    });
  }

  @override
  Future<void> put(Stream<DataRecord> records) async {
    final futures = <Future>[];
    await for(var record in records) {
      if(record.isDelete) {
        futures.add(executor.add(() => idb.transaction('repo', 'readwrite').objectStore('repo').delete(record.id)));
      } else {
        futures.add(executor.add(() => idb.transaction('repo', 'readwrite').objectStore('repo').put(record.toString(), record.id)));
      }
    }
    return Future.wait(futures);
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
