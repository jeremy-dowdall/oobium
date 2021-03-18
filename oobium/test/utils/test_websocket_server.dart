import 'dart:async';
import 'dart:io' as io;

import 'package:oobium/oobium.dart';

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
    server._subscription = server._http.listen((req) async {
      final ws = await WebSocket();
      await server._onUpgrade(ws);
      await ws.upgrade(req);
    });
    return server;
  }
  Future<void> close() async {
    await _subscription.cancel();
    await _http.close(force: true);
  }
}
