import 'dart:html';
import 'dart:indexed_db';

import 'data_base.dart' as base;

class Data extends base.Data {

  Data(String path) : super(path);

  @override
  Future<void> create() async {
    await window.indexedDB.open(path, version: 1, onUpgradeNeeded: (event) async {
      final upgradeDb = event.target.result as Database;
      if(!upgradeDb.objectStoreNames.contains('repo')) {
        final objectStore = upgradeDb.createObjectStore('repo');
        await objectStore.transaction.completed;
      }
    });
  }

  @override
  Future<void> destroy() => window.indexedDB.deleteDatabase(path);

}