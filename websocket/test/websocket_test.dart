import 'dart:async';

import 'package:oobium_websocket/src/logging.dart';
import 'package:oobium_websocket/src/websocket.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';

Future<void> main() async {

  // setUp(() async {
  //   await client?.close();
  //   client = (await WebSocket.connect(address: '127.0.0.1', port: 8001))..start();
  // });
  // tearDown(() async {
  //   await client?.close();
  //   client = null;
  // });

  log.level = Level.fine;

  group('test message', () {
    test('id', () {
      expect(WsMessage.get(true, '/path').id, endsWith('0'));
      expect(WsMessage.get(true, '/path').id, endsWith('0'));
      expect(WsMessage.get(false, '/path').id, endsWith('1'));
      expect(WsMessage.get(false, '/path').id, endsWith('1'));
    });
    test('single segment path without data', () {
      final input = WsMessage.get(true, '/path');
      final id = MessageId.current(true);
      expect(input.toString(), '$id:0|G/path');
      final output = WsMessage.parse(input.toString());
      expect(output.id, id);
      expect(output.channel, '0');
      expect(output.type, 'G');
      expect(output.path, '/path');
      expect(output.data, isNull);
    });
    test('multi segment path without data', () {
      final input = WsMessage.get(true, '/path/to/something');
      final id = MessageId.current(true);
      expect(input.toString(), '$id:0|G/path/to/something');
      final output = WsMessage.parse(input.toString());
      expect(output.id, id);
      expect(output.channel, '0');
      expect(output.type, 'G');
      expect(output.path, '/path/to/something');
      expect(output.data, isNull);
    });
    test('with String data', () {
      final input = WsMessage.put(false, '/path', 'data');
      final id = MessageId.current(false);
      expect(input.toString(), '$id:0|P/path "data"');
      final output = WsMessage.parse(input.toString());
      expect(output.id, id);
      expect(output.channel, '0');
      expect(output.type, 'P');
      expect(output.path, '/path');
      expect(output.data, 'data');
    });
    test('with int data', () {
      final input = WsMessage.put(true, '/path', 123);
      final id = MessageId.current(true);
      expect(input.toString(), '$id:0|P/path 123');
      final output = WsMessage.parse(input.toString());
      expect(output.data, 123);
    });
    test('with Map data', () {
      final input = WsMessage.put(true, '/path', {'1': 2, '2': 3});
      final id = MessageId.current(true);
      expect(input.toString(), '$id:0|P/path {"1":2,"2":3}');
      final output = WsMessage.parse(input.toString());
      expect(output.data, {'1': 2, '2': 3});
    });
    test('with List data', () {
      final input = WsMessage.put(true, '/path', [1,2,3]);
      final id = MessageId.current(true);
      expect(input.toString(), '$id:0|P/path [1,2,3]');
      final output = WsMessage.parse(input.toString());
      expect(output.data, [1, 2, 3]);
    });
    test('as without data', () {
      final msg = WsMessage.get(true, '/path').as('200');
      final id = MessageId.current(true);
      expect(msg.toString(), '$id:0|200');
      final output = WsMessage.parse(msg.toString());
      expect(output.id, id);
      expect(output.type, '200');
      expect(output.path, '');
      expect(output.data, isNull);
    });
    test('as with data', () {
      final msg = WsMessage.put(true, '/path', 'data').as('200');
      final id = MessageId.current(true);
      expect(msg.toString(), '$id:0|200');
      final output = WsMessage.parse(msg.toString());
      expect(output.id, id);
      expect(output.type, '200');
      expect(output.path, '');
      expect(output.data, isNull);
    });
    test('as with data, copied', () {
      final msg = WsMessage.put(true, '/path', 'data').as('200', 'other');
      final id = MessageId.current(true);
      expect(msg.toString(), '$id:0|200 "other"');
      final output = WsMessage.parse(msg.toString());
      expect(output.id, id);
      expect(output.type, '200');
      expect(output.path, '');
      expect(output.data, 'other');
    });
  });

  group('test on routing', () {
    test('error on duplicate path', () {
      final ws = WebSocket();
      ws.on.get('/dup', (_) => null);
      expect(() => ws.on.get('/dup', (_) => null), throwsA(equals('duplicate route: Get/dup')));
    });
    test('get, getStream and putStream on same path', () {
      final ws = WebSocket();
      expect(ws.on.get('/path', (_) => null), isA<WsSubscription>());
      expect(ws.on.getStream('/path', (_) => Stream.empty()), isA<WsSubscription>());
      expect(ws.on.putStream('/path', (_) => null), isA<WsSubscription>());
    });
    test('error on duplicate path with variables', () {
      final ws = WebSocket();
      ws.on.get('/dup/<id>', (_) => null);
      expect(() => ws.on.get('/dup/<name>', (_) => print('hi')), throwsA('duplicate route: Get/dup/<name>'));
    });
  });

  group('test connection', () {
    test('closed by client', () async {
      final server = await WsTestServerClient.start(8001);
      final client = await WebSocket('client').connect(port: 8001);
      server.done.then(expectAsync1((_) {}, count: 1));
      await client.close();
    });
    test('closed by server', () async {
      final server = await WsTestServerClient.start(8001);
      final client = await WebSocket('client').connect(port: 8001);
      client.done.then(expectAsync1((_) {}, count: 1));
      await server.close();
    });
    test('closed by client with active requests', () async {
      final server = await WsTestServerClient.start(8001);
      final client = await WebSocket('client').connect(port: 8001);
      client.get('/delay/10').then(expectAsync1((result) {
        expect(result.isSuccess, isFalse);
        expect(result.code, 499);
      }, count: 1));
      client.get('/echo/hi').then(expectAsync1((result) {
        expect(result.isSuccess, isFalse);
        expect(result.code, 499);
      }, count: 1));
      client.get('/echo/bye').then(expectAsync1((result) {
        expect(result.isSuccess, isFalse);
        expect(result.code, 499);
      }, count: 1));
      await client.close();
    });
    test('request after socket is closed by client', () async {
      final server = await WsTestServerClient.start(8001);
      final client = await WebSocket('client').connect(port: 8001);
      await client.close();
      final result = await client.get('/echo/hi');
      expect(result.isSuccess, isFalse);
      expect(result.code, 499);
    });
    test('request after socket is closed by server', () async {
      final server = await WsTestServerClient.start(8001);
      final client = await WebSocket('client').connect(port: 8001);
      await server.close();
      final result = await client.get('/echo/hi');
      expect(result.isSuccess, isFalse);
      expect(result.code, 444);
    });
  });

  group('test get', () {
    test('single get with url params', () async {
      final server = await WsTestServerClient.start(8001);
      final client = await WebSocket('client').connect(port: 8001);
      final result = await client.get('/echo/hello');
      expect(result.code, 200);
      expect(result.data, 'hello');
    });
    test('multiple gets, client (url params) and server (404)', () async {
      final server = await WsTestServerClient.start(8001);
      final client = await WebSocket('client').connect(port: 8001);
      final results = await Future.wait([
        client.get('/echo/hello'),
        server.get('/boom'),
        client.get('/echo/goodbye'),
      ]);
      expect(results.length, 3);
      expect(results[0].code, 200);
      expect(results[0].data, 'hello');
      expect(results[1].code, 404);
      expect(results[1].data, isNull);
      expect(results[2].code, 200);
      expect(results[2].data, 'goodbye');
    });
    test('get data', () async {
      final server = await WsTestServerClient.start(8001);
      final client = await WebSocket('client').connect(port: 8001);
      final result = await client.get('/data');
      expect(result.code, 200);
      expect(result.data, [1, 2, 3, 4, 5, 6, 7, 8, 9, 0]);
    });
    test('out of order', () async {
      final server = await WsTestServerClient.start(8001);
      final client = await WebSocket('client').connect(port: 8001);
      final events = [];
      client.get('/delay/10').then((_) => events.add('delay'));
      client.get('/echo/hi').then((_) => events.add('echo'));
      await client.flush();
      expect(events, ['echo', 'delay']);
    });
  });

  group('test getStream', () {
    test('get stream', () async {
      final server = await WsTestServerClient.start(8001);
      final client = await WebSocket('client').connect(port: 8001);
      final stream = client.getStream('/stream');
      expect(await stream.toList(), [[1, 2, 3],[4, 5, 6],[7, 8, 9]]);
    });
    test('get stream with delays', () async {
      final server = await WsTestServerClient.start(8001);
      final client = await WebSocket('client').connect(port: 8001);
      final stream = client.getStream('/stream/delay/1/2/3');
      expect(await stream.toList(), [[1, 2, 3],[4, 5, 6],[7, 8, 9]]);
    });
    test('get stream mixed with simple gets', () async {
      final server = await WsTestServerClient.start(8001);
      final client = await WebSocket('client').connect(port: 8001);
      final events = [];
      client.get('/delay/100').then((e) => events.add('hi 1'));
      client.getStream('/stream/delay/0/50/150').listen((e) => events.add(e));
      client.get('/delay/0').then((e) => events.add('hi 2'));
      client.get('/echo/hi').then((e) => events.add('hi'));
      await client.flush();
      expect(events, ['hi', [1, 2, 3], 'hi 2', [4, 5, 6], 'hi 1', [7, 8, 9]]);
    });
    test('get multiple streams', () async {
      final server = await WsTestServerClient.start(8001);
      final client = await WebSocket('client').connect(port: 8001);
      final events = [];
      client.getStream('/stream1').listen((e) => events.add(e));
      client.getStream('/stream2').listen((e) => events.add(e));
      client.getStream('/stream3').listen((e) => events.add(e));
      await client.flush();
      expect(events, [[1, 2, 3], [1, 5, 6], [1, 8, 9], [2, 2, 3], [2, 5, 6], [2, 8, 9], [3, 2, 3], [3, 5, 6], [3, 8, 9]]);
    });
  });

  group('test put', () {
    test('put String', () async {
      final server = await WsTestServerClient.start(8001);
      final client = await WebSocket('client').connect(port: 8001);
      final result = await client.put('/data', 'test-string');
      expect(result.isSuccess, isTrue);
      expect(result.code, 200);
      expect(result.data, isNull);
      expect(await server.data, 'test-string');
    });
    test('put data', () async {
      final server = await WsTestServerClient.start(8001);
      final client = await WebSocket('client').connect(port: 8001);
      await client.put('/data', [1, 2, 3, 4, 5, 6, 7, 8, 9, 0]);
      expect(await server.data, [1, 2, 3, 4, 5, 6, 7, 8, 9, 0]);
    });
  });

  group('test putStream', () {
    test('put data stream', () async {
      final server = await WsTestServerClient.start(8001);
      final client = await WebSocket('client').connect(port: 8001);
      final data = [[1, 2, 3, 4, 5, 6, 7, 8, 9, 0],[255, 0xFF, 3, 4, 5, 6, 7, 8, 9, 0],[1, 2, 3, 4, 5, 6, 7, 8, 9, 0]];
      final result = await client.putStream('/stream', Stream.fromIterable(data));
      expect(result.code, 200);
      expect(await server.data, data);
    });
  });

  group('test anonymous listeners', () {
    test('request socket, published channel', () async {
      final server = await WsTestServerClient.start(8001);
      final client = await WebSocket('client').connect(port: 8001);
      final events = [];
      client.on.get('/pong/<msg>', (req) {
        events.add(req['msg']);
        return req['msg'];
      });
      await client.get('/ping/hi').then((result) => events.add(result.data));
      expect(events, ['hi', 'hi']);
    });
    test('request socket, anonymous channel', () async {
      final server = await WsTestServerClient.start(8001);
      final client = await WebSocket('client').connect(port: 8001);
      final events = [];
      client.on.get('/pong/<msg>', (req) {
        events.add('nope');
        return req['msg'];
      });
      await client.get('/ping/hi',
          WsHandlers()..get('/pong/<msg>', (req) {
            events.add(req['msg']);
            return req['msg'];
          })
      ).then((result) => events.add(result.data));
      expect(events, ['hi', 'hi']);
    });
    test('2 clients', () async {
      final server = await WsTestServerClient.start(8001);
      final client1 = await WebSocket('client1').connect(port: 8001);
      final client2 = await WebSocket('client2').connect(port: 8001);
      final events = [];
      client1.get('/ping/hi',
          WsHandlers()..get('/pong/<msg>', (req) {
            events.add(req['msg']);
            return req['msg'];
          })
      ).then((result) => events.add(result.data));
      client2.get('/ping/bye',
          WsHandlers()..get('/pong/<msg>', (req) async {
            events.add(req['msg']);
            await Future.delayed(Duration(milliseconds: 100));
            return req['msg'];
          })
      ).then((result) => events.add(result.data));
      await client1.flush();
      await client2.flush();
      expect(events, ['hi', 'bye', 'hi', 'bye']);
    });
    test('request.socket to published channel', () async {
      final server = await WsTestServerClient.start(8001);
      final client = await WebSocket('client').connect(port: 8001);
      client.on.get('/pong/<msg>', (req) async {
        return req.socket.get('/echo/bye');
      });
      final result = await client.get('/ping/hello');
      expect(result.isSuccess, isTrue);
      expect(result.data, 'bye');
    });
  });
}

class WsTestServerClient {

  static Future<WsTestServerClient> start(int port) async {
    final server = WsTestServerClient(spawnHybridUri('websocket_test_server.dart', message: port));
    await server.ready;
    return server;
  }

  final _ready = Completer();
  final _done = Completer();
  final StreamChannel channel;
  WsTestServerClient(this.channel) {
    channel.stream.listen((msg) {
      if(msg == 'ready') {
        _ready.complete();
      }
      else if(msg == 'done') {
        _done.complete();
      }
      else if(completer != null && !completer!.isCompleted) {
        completer!.complete(msg);
        completer = null;
      }
    });
  }

  Future<void> get ready => _ready.future;
  Future<void> get done => _done.future;

  Future<WsResult> get(String path) => _send('get', path).then((json) => WsResult(json['code'], json['data']));
  Future get data => _send('getData');

  Future<void> close() => _send('close');

  Completer? completer;
  Future _send(String path, [dynamic data]) async {
    await completer?.future;
    completer = Completer();
    channel.sink.add([path, data]);
    return completer!.future;
  }
}
