import 'dart:html';
import 'dart:indexed_db';

import 'package:oobium_common/src/data/executor.dart';
import 'package:oobium_common/src/database.dart' show DataRecord;

import 'repo_base.dart' as base;

class Repo extends base.Repo {

  Repo(String db) : super(db);

  Database idb;
  final executor = Executor();

  @override
  Future<Repo> open() async {
    idb = await window.indexedDB.open(db);
    return this;
  }

  @override
  Future<void> close({bool cancel = false}) async {
    await executor.close(cancel: cancel ?? false);
    idb.close();
    idb = null;
    return Future.value();
  }

  @override
  Stream<DataRecord> get([int timestamp]) {
    return idb.transaction('repo', 'readonly').objectStore('repo').openCursor(autoAdvance: true).map((event) {
      return DataRecord.fromLine(event.value);
    });
  }

  @override
  void put(Stream<DataRecord> records) async {
    await for(var record in records) {
      if(record.isDelete) {
        executor.add(() => idb.transaction('repo', 'readwrite').objectStore('repo').delete(record.id));
      } else {
        executor.add(() => idb.transaction('repo', 'readwrite').objectStore('repo').put(record.toString(), record.id));
      }
    }
  }
}
