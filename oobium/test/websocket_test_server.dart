import 'dart:async';
import 'dart:io';

import 'package:oobium/src/websocket.dart';
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

  WebSocket ws;
  var wsData;

  Future<void> start(int port) async {
    await TestWebsocketServer.start(port: port, onUpgrade: (socket) async {
      ws = socket;
      ws.done.then((_) {
        channel.sink.add('done');
      });
      ws.on.get('/delay/<millis>', (req, res) async {
        await Future.delayed(Duration(milliseconds: int.parse(req['millis'])));
        res.send(code: 200);
      });
      ws.on.get('/echo/<msg>', (req, res) {
        res.send(data: req.params['msg']);
      });
      ws.on.get('/data', (req, res) {
        res.send(data: [1, 2, 3, 4, 5, 6, 7, 8, 9, 0]);
      });
      ws.on.get('/stream', (req, res) {
        res.send(data: Stream.fromIterable([[1, 2, 3, 4, 5, 6, 7, 8, 9, 0],[1, 2, 3, 4, 5, 6, 7, 8, 9, 0],[1, 2, 3, 4, 5, 6, 7, 8, 9, 0]]));
      });
      ws.on.put('/data', (req, res) {
        wsData = req.data.value;
      });
      ws.on.put('/stream', (req, res) async {
        final completer = Completer<List<List<int>>>();
        wsData = completer.future;
        final d = await req.data.stream.toList();
        completer.complete(d);
      });
      ws.on.put('/file', (req, res) async {
        final completer = Completer<List<List<int>>>();
        wsData = completer.future;
        final d = await req.data.stream.toList();
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