import 'dart:async';
import 'dart:html';
import 'dart:indexed_db';

import 'package:oobium_datastore/src/datastore/data.dart';
import 'package:oobium_datastore/src/datastore/data_.dart' as base;

class DataPlatform implements base.DataPlatform {

  final Data data;
  DataPlatform(this.data);

  Database? idb;

  Future<void> open({int? version, FutureOr<bool> Function(DataUpgradeEvent event)? onUpgrade}) async {
    assert(window.indexedDB != null);
    idb = await window.indexedDB!.open('${data.path}/$version', version: version,
      onUpgradeNeeded: (event) async {
        final oldVersion = event.oldVersion ?? 0;
        if(oldVersion < 1) {
          final upgradeDb = event.target.result as Database;
          if(upgradeDb.objectStoreNames?.contains('repo') != true) {
            upgradeDb.createObjectStore('repo');
          }
          if(upgradeDb.objectStoreNames?.contains('sync') != true) {
            upgradeDb.createObjectStore('sync');
          }
        }
        final newVersion = event.newVersion ?? ((oldVersion == 0) ? 1 : oldVersion);
        if(newVersion != oldVersion) {
          final oldData = (oldVersion > 0) ? (await Data(data.path).open(version: oldVersion)) : null;
          final updated = (await onUpgrade?.call(DataUpgradeEvent(oldVersion, oldData, newVersion, data))) ?? true;
          if(updated) {
            await oldData?.destroy();
          }
        }
      },
      onBlocked: (event) async {
        print('onBlocked');
      }
    );
  }

  dynamic connect() {
    return idb;
  }

  Future<void> close() async {
    idb = null;
  }

  Future<void> destroy() async {
    await window.indexedDB?.deleteDatabase(data.path);
  }
}
