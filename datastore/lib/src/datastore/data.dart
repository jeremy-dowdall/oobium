import 'dart:async';

import 'data_.dart'
  if (dart.library.io) 'data_io.dart'
  if (dart.library.html) 'data_html.dart';

class Data {

  final String path;
  final _connections = <DataConnection>[];
  late final DataPlatform _platform;
  Data(this.path) {
    _platform = DataPlatform(this);
  }

  Future<Data> open({int? version, FutureOr<bool> Function(DataUpgradeEvent event)? onUpgrade}) async {
    await _platform.open(version: version, onUpgrade: onUpgrade);
    return this;
  }

  dynamic connect(DataConnection connection) {
    _connections.add(connection);
    return _platform.connect();
  }

  Future<void> close() async {
    for(var connection in _connections) {
      await connection.close();
    }
    await _platform.close();
  }

  Future<void> destroy() async {
    await _platform.destroy();
  }
}

abstract class DataConnection {
  Future<void> close();
}

class DataUpgradeEvent {
  final int oldVersion;
  final Data? oldData;
  final int newVersion;
  final Data newData;
  DataUpgradeEvent(this.oldVersion, this.oldData, this.newVersion, this.newData);
}
