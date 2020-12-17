import 'dart:html' hide WebSocket;
import 'dart:indexed_db';

import 'package:oobium_common/src/data/executor.dart';
import 'package:oobium_common/src/data/repo.dart';
import 'package:oobium_common/src/websocket.dart';

import 'sync_base.dart' as base;

class Sync extends base.Sync {

  Sync(String db, Repo repo) : super(db, repo);

  Database idb;
  final executor = Executor();

  @override
  Future<Sync> open() async {
    idb = await window.indexedDB.open(db, version: 1, onUpgradeNeeded: (event) async {
      final upgradeDb = event.target.result as Database;
      if(!upgradeDb.objectStoreNames.contains('repo')) {
        final objectStore = upgradeDb.createObjectStore('repo');
        await objectStore.transaction.completed;
      }
    });
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
  Future<void> save() async {
    print('TODO save (html)');
  }
}

class Binder extends base.Binder {

  Binder(Sync sync, WebSocket socket) : super(sync, socket);

}

class Replicant extends base.Replicant {

  Replicant(String db, String id) : super(db, id);

}
