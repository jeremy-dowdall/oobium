import 'dart:async';
import 'dart:io' as io;
import 'dart:isolate';

import 'package:oobium_common/oobium_common.dart';

abstract class TestDatabaseServer extends TestIsolate {

  Future<Map<String, dynamic>> dbGet(String id) => send<Map<String, dynamic>>('/db/get', id);
  Future<Map<String, dynamic>> dbPut(DataModel model) => send<Map<String, dynamic>>('/db/put', model);

  Future<int> get dbModelCount => send<int>('/db/count/models');

  Future<void> destroy() async {
    await send('/db/destroy');
    return stop();
  }

  final String path;
  final int port;
  TestDatabaseServer({this.path, this.port});

  Database _db;
  TestWebsocketServer _server;

  Database onCreateDatabase();

  @override
  Future<void> onStart() async {
    _db = onCreateDatabase();
    await _db.reset();
    _server = await TestWebsocketServer.start(port: port, onUpgrade: (socket) async {
      _db.bind(socket);
    });
  }

  @override
  Future<void> onStop() {
    return _server.close();
  }

  @override
  FutureOr onMessage(String path, data) {
    if(path == '/db/destroy') return _db?.destroy();
    if(path == '/db/get') return _db?.get(data as String)?.toJson();
    if(path == '/db/put') return _db?.put(data as DataModel)?.toJson();
    if(path == '/db/count/models') return _db?.getAll()?.length ?? 0;
  }
}

class TestWebsocketServer {

  final int port;

  io.HttpServer _http;
  StreamSubscription _subscription;
  Future<void> Function(WebSocket socket) _onUpgrade;

  TestWebsocketServer._(this.port);

  static Future<TestWebsocketServer> start({int port = 8080, Future<void> Function(WebSocket socket) onUpgrade}) async {
    final server = TestWebsocketServer._(port);
    server._onUpgrade = onUpgrade;
    server._http = await io.HttpServer.bind('127.0.0.1', port);
    server._subscription = server._http.listen((httpRequest) async => await server._handle(httpRequest));
    return server;
  }
  Future<void> close() async {
    await _subscription.cancel();
    await _http.close(force: true);
  }

  Future<void> _handle(io.HttpRequest request) async {
    final socket = WsSocket(await io.WebSocketTransformer.upgrade(request));
    return _onUpgrade(WebSocket(socket)..start());
  }
}

abstract class TestIsolate {

  Future<void> onStart();
  Future<void> onStop();
  FutureOr<dynamic> onMessage(String path, dynamic data);

  static Future<T> start<T extends TestIsolate>(T isolate) async {
    final receivePort = ReceivePort();
    isolate._isolate = _TestIsolate._(
      await Isolate.spawn(_TestIsolate._init, receivePort.sendPort, errorsAreFatal: true, debugName: isolate.runtimeType.toString()),
      await receivePort.first
    );
    await isolate._isolate.send('_isolate_', isolate);
    return isolate;
  }

  Future<void> stop() {
    return _isolate.stop();
  }

  _TestIsolate _isolate;
  Future<T> send<T>(String path, [dynamic data]) => _isolate.send<T>(path, data);
}

class _TestIsolate {
  final Isolate _isolate;
  final SendPort _sendPort;
  _TestIsolate._(this._isolate, this._sendPort);

  Future<void> stop() async {
    await _runner?.onStop();
    _isolate.kill();
  }

  Future<T> send<T>(String path, [dynamic data]) async {
    final port = ReceivePort();
    _sendPort.send([path, data, port.sendPort]);
    return (await port.first) as T;
  }

  static TestIsolate _runner;
  static Future<void> _init(SendPort sendPort) async {
    final port = ReceivePort();
    sendPort.send(port.sendPort);
    await for(var msg in port) {
      if(msg[0] == '_isolate_') {
        _runner = msg[1];
        await _runner.onStart();
        (msg[2] as SendPort).send(200);
      }
      else if(_runner != null) {
        (msg[2] as SendPort).send(await _runner.onMessage(msg[0], msg[1]));
      }
      else {
        (msg[2] as SendPort).send(404);
      }
    }
  }
}
