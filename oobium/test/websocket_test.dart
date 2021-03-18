import 'dart:async';

import 'package:oobium/src/websocket.dart';
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

  group('test message', () {
    test('without data', () {
      final input = WsMessage(type: 'REQ', id: '0123456789012', method: 'GET', path: '/path');
      expect(input.toString(), 'REQ:0123456789012:GET/path');
      final output = WsMessage.parse(input.toString());
      expect(output.type, 'REQ');
      expect(output.isRequest, isTrue);
      expect(output.id, '0123456789012');
      expect(output.method, 'GET');
      expect(output.path, '/path');
      expect(output.data, isNull);
    });
    test('with String data', () {
      final input = WsMessage(type: 'REQ', id: '0123456789012', method: 'GET', path: '/path', data: 'data');
      expect(input.toString(), 'REQ:0123456789012:GET/path "data"');
      final output = WsMessage.parse(input.toString());
      expect(output.type, 'REQ');
      expect(output.isRequest, isTrue);
      expect(output.id, '0123456789012');
      expect(output.method, 'GET');
      expect(output.path, '/path');
      expect(output.data, 'data');
    });
    test('with int data', () {
      final input = WsMessage(type: 'REQ', id: '0123456789012', method: 'GET', path: '/path', data: 123);
      expect(input.toString(), 'REQ:0123456789012:GET/path 123');
      final output = WsMessage.parse(input.toString());
      expect(output.data, 123);
    });
    test('with Map data', () {
      final input = WsMessage(type: 'REQ', id: '0123456789012', method: 'GET', path: '/path', data: {'1': 2, '2': 3});
      expect(input.toString(), 'REQ:0123456789012:GET/path {"1":2,"2":3}');
      final output = WsMessage.parse(input.toString());
      expect(output.data, {'1': 2, '2': 3});
    });
    test('with List data', () {
      final input = WsMessage(type: 'REQ', id: '0123456789012', method: 'GET', path: '/path', data: [1,2,3]);
      expect(input.toString(), 'REQ:0123456789012:GET/path [1,2,3]');
      final output = WsMessage.parse(input.toString());
      expect(output.data, [1, 2, 3]);
    });
  });

  group('test on routing', () {
    test('error on duplicate path', () {
      final ws = WebSocket();
      ws.on.get('/dup', (req, res) => print('hi'));
      expect(() => ws.on.get('/dup', (req, res) => print('hi')), throwsA(equals('duplicate route: GET/dup')));
    });
    test('error on duplicate path with variables', () {
      final ws = WebSocket();
      ws.on.get('/dup/<id>', (req, res) => print('hi'));
      expect(() => ws.on.get('/dup/<name>', (req, res) => print('hi')), throwsA('duplicate route: GET/dup/<name>'));
    });
  });

  group('test connection', () {
    test('closed by client', () async {
      final server = await WsTestServerClient.start(8001);
      final client = await WebSocket().connect(port: 8001);
      server.done.then(expectAsync1((_) {
        print('done');
      }, count: 1));
      await client.close();
    });
    test('closed by server', () async {
      final server = await WsTestServerClient.start(8001);
      final client = await WebSocket().connect(port: 8001);
      client.done.then(expectAsync1((_) {
        print('done');
      }, count: 1));
      await server.close();
    });
    test('closed by client with active requests', () async {
      final server = await WsTestServerClient.start(8001);
      final client = await WebSocket().connect(port: 8001);
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
      final client = await WebSocket().connect(port: 8001);
      await client.close();
      final result = await client.get('/echo/hi');
      expect(result.isSuccess, isFalse);
      expect(result.code, 499);
    });
    test('request after socket is closed by server', () async {
      final server = await WsTestServerClient.start(8001);
      final client = await WebSocket().connect(port: 8001);
      await server.close();
      final result = await client.get('/echo/hi');
      expect(result.isSuccess, isFalse);
      expect(result.code, 444);
    });
  });

  group('test gets', () {
    test('single get with url params', () async {
      final server = await WsTestServerClient.start(8001);
      final client = await WebSocket().connect(port: 8001);
      final result = await client.get('/echo/hello');
      expect(result.code, 200);
      expect(result.data, 'hello');
    });
    test('multiple gets, client (url params) and server (404)', () async {
      final server = await WsTestServerClient.start(8001);
      final client = await WebSocket().connect(port: 8001);
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
      final client = await WebSocket().connect(port: 8001);
      final result = await client.get('/data');
      expect(result.code, 200);
      expect(result.data, [1, 2, 3, 4, 5, 6, 7, 8, 9, 0]);
    });
    test('get data stream', () async {
      final server = await WsTestServerClient.start(8001);
      final client = await WebSocket().connect(port: 8001);
      final result = await client.get('/stream');
      expect(result.code, 100);
      expect(result.data, isA<Stream>());
      final fsData = [[1, 2, 3, 4, 5, 6, 7, 8, 9, 0],[1, 2, 3, 4, 5, 6, 7, 8, 9, 0],[1, 2, 3, 4, 5, 6, 7, 8, 9, 0]];
      final wsData = (await (result.data as Stream<List<int>>).toList());
      expect(wsData, fsData);
    });
  });

  group('test puts', () {
    test('put String', () async {
      final server = await WsTestServerClient.start(8001);
      final client = await WebSocket().connect(port: 8001);
      final result = await client.put('/data', 'test-string');
      expect(result.isSuccess, isTrue);
      expect(result.code, 200);
      expect(result.data, isNull);
      expect(await server.data, 'test-string');
    });
    test('put data', () async {
      final server = await WsTestServerClient.start(8001);
      final client = await WebSocket().connect(port: 8001);
      await client.put('/data', [1, 2, 3, 4, 5, 6, 7, 8, 9, 0]);
      expect(await server.data, [1, 2, 3, 4, 5, 6, 7, 8, 9, 0]);
    });
    test('put data stream', () async {
      final server = await WsTestServerClient.start(8001);
      final client = await WebSocket().connect(port: 8001);
      final data = [[1, 2, 3, 4, 5, 6, 7, 8, 9, 0],[255, 0xFF, 3, 4, 5, 6, 7, 8, 9, 0],[1, 2, 3, 4, 5, 6, 7, 8, 9, 0]];
      final result = await client.put('/stream', Stream.fromIterable(data));
      expect(result.code, 200);
      expect(await server.data, data);
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
      else if(completer != null && !completer.isCompleted) {
        completer.complete(msg);
        completer = null;
      }
    });
  }

  Future<void> get ready => _ready.future;
  Future<void> get done => _done.future;

  Future<WsResult> get(String path) => _send('get', path).then((json) => WsResult(json['code'], json['data']));
  Future get data => _send('getData');

  Future<void> close() => _send('close');

  Completer completer;
  Future _send(String path, [dynamic data]) async {
    await completer?.future;
    completer = Completer();
    channel.sink.add([path, data]);
    return completer.future;
  }
}
