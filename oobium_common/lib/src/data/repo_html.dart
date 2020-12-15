import 'dart:html';
import 'dart:indexed_db';

import 'package:oobium_common/src/data/executor.dart';
import 'package:oobium_common/src/database.dart' show DataRecord;

import 'repo_base.dart' as base;

class Repo extends base.Repo {

  Repo(String path) : super(path);

  Database db;
  final executor = Executor();

  Future<void> open() async {
    db = await window.indexedDB.open(path, version: 1, onUpgradeNeeded: (event) async {
      final upgradeDb = event.target.result as Database;
      if(!upgradeDb.objectStoreNames.contains('repo')) {
        final objectStore = upgradeDb.createObjectStore('repo');
        await objectStore.transaction.completed;
      }
    });
  }

  Future<void> close() async {
    await executor.close();
    db.close();
    db = null;
    return Future.value();
  }

  Future<void> destroy() async {
    await executor.close(cancel: true);
    db.close();
    db = null;
    // TODO this destroys the whole database, something we probably want, but not at this level (in the repo class)
    await window.indexedDB.deleteDatabase(path);
  }

  Stream<DataRecord> read() {
    return db.transaction('repo', 'readonly').objectStore('repo').openCursor(autoAdvance: true).map((event) {
      return DataRecord.fromLine(event.value);
    });
  }
  
  void write(Iterable<DataRecord> records) {
    for(var record in records) {
      if(record.isDelete) {
        executor.add(() => db.transaction('repo', 'readwrite').objectStore('repo').delete(record.id));
      } else {
        executor.add(() => db.transaction('repo', 'readwrite').objectStore('repo').put(record.toString(), record.id));
      }
    }
  }

  Future<void> writeStream(Stream<String> lines) async {
    await for(var record in lines.map((line) => DataRecord.fromLine(line))) {
      executor.add(() => db.transaction('repo', 'readwrite').objectStore('repo').put(record.toString(), record.id));
    }
  }
}
