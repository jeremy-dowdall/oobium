import 'dart:async';
import 'dart:io';

class Data {

  final String path;
  final _connections = <Connection>[];
  Data(this.path);

  Directory? dir;

  Future<Data> open({int? version, FutureOr<bool> Function(DataUpgradeEvent event)? onUpgrade}) async {
    final vf = File('$path/version');
    final oldVersion = (await vf.exists()) ? int.parse(await vf.readAsString()) : 0;
    final newVersion = version ?? ((oldVersion == 0) ? 1 : oldVersion);
    dir = Directory('$path/$newVersion');
    if(!await dir!.exists()) {
      await dir!.create(recursive: true);
    }
    if(newVersion != oldVersion) {
      final oldData = (oldVersion > 0) ? (await Data(path).open(version: oldVersion)) : null;
      final upgraded = (await onUpgrade?.call(DataUpgradeEvent(oldVersion, oldData, newVersion, this))) ?? true;
      if(upgraded) {
        await vf.writeAsString(newVersion.toString());
        await oldData?.destroy();
      }
    }
    return this;
  }

  dynamic connect(Connection connection) {
    _connections.add(connection);
    return dir!.path;
  }

  Future<void> close() async {
    for(var connection in _connections) {
      await connection.close();
    }
    dir = null;
  }

  Future<void> destroy() async {
    await close();
    final dir = Directory(path);
    if(await dir.exists()) {
      await dir.delete(recursive: true).catchError((_) {
        print('destroy failed');
      });
    }
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
