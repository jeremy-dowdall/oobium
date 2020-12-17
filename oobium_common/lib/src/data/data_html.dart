import 'dart:html';
import 'dart:indexed_db';

import 'data_base.dart' as base;

class Data extends base.Data {

  Data(String path, {int version = 1}) : super(path, version:  version);

  Database idb;

  @override
  Future<Data> create() async {
    idb = await window.indexedDB.open(path, version: version,
      onUpgradeNeeded: (event) async {
        final upgradeDb = event.target.result as Database;
        if(!upgradeDb.objectStoreNames.contains('repo')) {
          final objectStore = upgradeDb.createObjectStore('repo');
          await objectStore.transaction.completed;
        }
      },
      onBlocked: (event) async {
        print('onBlocked');
      }
    );
    return this;
  }

  @override
  dynamic connect(base.Connection connection) {
    super.connect(connection);
    return idb;
  }

  @override
  Future<void> close({bool cancel = false}) async {
    await super.close(cancel: cancel ?? false);
    idb?.close();
    idb = null;
  }

  @override
  Future<void> destroy() async {
    await close(cancel: true);
    await window.indexedDB.deleteDatabase(path);
  }
}