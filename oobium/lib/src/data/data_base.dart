import 'dart:async';

class Data {

  final String path;
  Data(this.path);

  Future<Data> open({int version, FutureOr<bool> Function(DataUpgradeEvent event) onUpgrade}) => throw UnsupportedError('platform not supported');
  Future<void> destroy() => throw UnsupportedError('platform not supported');

  final _connections = <Connection>[];

  dynamic connect(Connection connection) {
    _connections.add(connection);
  }

  Future<void> close() async {
    for(var connection in _connections) {
      await connection.close();
    }
  }
}

abstract class Connection {
  Future<void> close();
}

class DataUpgradeEvent {
  final int oldVersion;
  final Data oldData;
  final int newVersion;
  final Data newData;
  DataUpgradeEvent(this.oldVersion, this.oldData, this.newVersion, this.newData);
}