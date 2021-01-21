import 'dart:async';
import 'dart:html';
import 'dart:indexed_db';

import 'data_base.dart' as base;

class Data extends base.Data {

  Data(String path) : super(path);

  Database idb;

  @override
  Future<Data> open({int version, FutureOr<bool> Function(base.DataUpgradeEvent event) onUpgrade}) async {
    idb = await window.indexedDB.open('$path/$version', version: version,
      onUpgradeNeeded: (event) async {
        if(event.oldVersion < 1) {
          final upgradeDb = event.target.result as Database;
          if(!upgradeDb.objectStoreNames.contains('repo')) {
            upgradeDb.createObjectStore('repo');
          }
          if(!upgradeDb.objectStoreNames.contains('sync')) {
            upgradeDb.createObjectStore('sync');
          }
        }
        if(event.newVersion != event.oldVersion) {
          final oldData = (event.oldVersion > 0) ? (await Data(path).open(version: event.oldVersion)) : null;
          final updated = (await onUpgrade?.call(base.DataUpgradeEvent(event.oldVersion, oldData, event.newVersion, this))) ?? true;
          if(updated) {
            await oldData?.destroy();
          }
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
  Future<void> close() async {
    await super.close();
    idb?.close();
    idb = null;
  }

  @override
  Future<void> destroy() async {
    await close();
    await window.indexedDB.deleteDatabase(path);
  }
}