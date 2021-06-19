import 'dart:async';

import 'package:oobium_websocket/src/websocket.dart';
import 'package:stream_channel/stream_channel.dart';

import 'utils/test_websocket_server.dart';

Future<void> hybridMain(StreamChannel channel, dynamic message) async {

  print('server [$message]');
  
  final server = WsTestServer(channel);
  await server.start(message);
  server.listen();
  channel.sink.add('ready');

}

class WsTestServer {

  final StreamChannel channel;
  WsTestServer(this.channel);

  late WebSocket ws;
  var wsData;

  Future<void> start(int port) async {
    await TestWebsocketServer.start(port: port, onUpgrade: (socket) async {
      ws = socket;
      ws.done.then((_) {
        channel.sink.add('done');
      });
      ws.on.get('/delay/<millis>', (req) async {
        await Future.delayed(Duration(milliseconds: int.parse(req['millis'])));
        return 'done';
      });
      ws.on.get('/echo/<msg>', (req) {
        return req.params['msg'];
      });
      ws.on.get('/data', (req) {
        return [1, 2, 3, 4, 5, 6, 7, 8, 9, 0];
      });
      ws.on.getStream('/stream', (req) => Stream.fromIterable([
        [1, 2, 3], [4, 5, 6], [7, 8, 9]
      ]));
      ws.on.getStream('/stream1', (req) => Stream.fromIterable([
        [1, 2, 3], [1, 5, 6], [1, 8, 9]
      ]));
      ws.on.getStream('/stream2', (req) => Stream.fromIterable([
        [2, 2, 3], [2, 5, 6], [2, 8, 9]
      ]));
      ws.on.getStream('/stream3', (req) => Stream.fromIterable([
        [3, 2, 3], [3, 5, 6], [3, 8, 9]
      ]));
      ws.on.getStream('/stream/delay/<d0>/<d1>/<d2>', (req) => Stream.fromFutures([
        Future.delayed(Duration(milliseconds: int.parse(req['d0'])), () => [1, 2, 3]),
        Future.delayed(Duration(milliseconds: int.parse(req['d1'])), () => [4, 5, 6]),
        Future.delayed(Duration(milliseconds: int.parse(req['d2'])), () => [7, 8, 9]),
      ]));
      ws.on.put('/data', (req) {
        wsData = req.data;
      });
      ws.on.putStream('/stream', (req) async {
        final completer = Completer<List<List<int>>>();
        wsData = completer.future;
        final d = await req.stream.toList();
        completer.complete(d);
      });
      ws.on.putStream('/file', (req) async {
        final completer = Completer<List<List<int>>>();
        wsData = completer.future;
        final d = await req.stream.toList();
        completer.complete(d);
      });
    });
  }

  StreamSubscription listen() {
    return channel.stream.listen((msg) async {
      final result = await onMessage(msg[0], (msg.length > 1) ? msg[1] : null);
      channel.sink.add(result);
    });
  }

  FutureOr onMessage(String path, [dynamic data]) {
    switch(path) {
      case 'close': return ws.close();
      case 'getData': return wsData;
      case 'get': return ws.get(data).then((result) => result.asJson());
      default:
        return 404;
    }
  }
}

extension WsResultExt on WsResult {
  Map asJson() => {'code': code, 'data': data};
}