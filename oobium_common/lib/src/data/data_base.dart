class Data {

  final String path;
  final int version;
  Data(this.path, {this.version = 1});

  Future<Data> create() => throw UnsupportedError('platform not supported');
  Future<void> destroy() => throw UnsupportedError('platform not supported');

  final _connections = <Connection>[];

  dynamic connect(Connection connection) {
    _connections.add(connection);
  }

  Future<void> close({bool cancel = false}) async {
    for(var connection in _connections) {
      await connection.close(cancel: cancel);
    }
  }
}

abstract class Connection {
  Future<void> close({bool cancel = false});
}