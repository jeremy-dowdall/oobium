import 'dart:async';
import 'dart:io' as io;

import 'package:oobium_common/oobium_common.dart';

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
