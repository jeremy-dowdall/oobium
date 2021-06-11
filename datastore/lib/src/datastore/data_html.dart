import 'dart:async';
import 'dart:html';
import 'dart:indexed_db';

class Data {

  final String path;
  final _connections = <Connection>[];
  Data(this.path);

  Database? idb;

  Future<Data> open({int? version, FutureOr<bool> Function(DataUpgradeEvent event)? onUpgrade}) async {
    assert(window.indexedDB != null);
    idb = await window.indexedDB!.open('$path/$version', version: version,
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
          final oldData = (oldVersion > 0) ? (await Data(path).open(version: oldVersion)) : null;
          final updated = (await onUpgrade?.call(DataUpgradeEvent(oldVersion, oldData, newVersion, this))) ?? true;
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

  dynamic connect(Connection connection) {
    _connections.add(connection);
    return idb;
  }

  Future<void> close() async {
    for(var connection in _connections) {
      await connection.close();
    }
    idb?.close();
    idb = null;
  }

  Future<void> destroy() async {
    await close();
    await window.indexedDB?.deleteDatabase(path);
  }
}

abstract class Connection {
  Future<void> close();
}

class DataUpgradeEvent {
  final int oldVersion;
  final Data? oldData;
  final int newVersion;
  final Data newData;
  DataUpgradeEvent(this.oldVersion, this.oldData, this.newVersion, this.newData);
}
