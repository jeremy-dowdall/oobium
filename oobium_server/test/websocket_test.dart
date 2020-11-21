import 'dart:async';
import 'dart:io';

import 'package:oobium_common/oobium_common.dart';
import 'package:oobium_server/src/server.dart';
import 'package:test/test.dart';

void main() {
  Server server;
  ServerWebSocket wsServer;
  ClientWebSocket wsClient;

  setUp(() async {
    wsClient?.close();
    wsServer?.close();
    await server?.close();
    server = Server(address: '127.0.0.1', port: 8001);
    server.get('/', [websocket((socket) { wsServer = socket; })]);
    await server.start();
    wsClient = (await ClientWebSocket.connect(address: '127.0.0.1', port: 8001))..start();
  });
  tearDown(() async {
    wsClient?.close();
    wsClient = null;
    wsServer?.close();
    wsServer = null;
    await server?.close();
    server = null;
  });

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

  group('test gets', () {
    test('single get with url params', () async {
      wsServer.on.get('/echo/<msg>', (req, res) {
        res.send(data: req.params['msg']);
      });
      final result = await wsClient.get('/echo/hello');
      expect(result.code, 200);
      expect(result.data, 'hello');
    });
    test('multiple gets, client (url params) and server (404)', () async {
      wsServer.on.get('/echo/<msg>', (req, res) {
        res.send(data: req.params['msg']);
      });
      final results = await Future.wait([
        wsClient.get('/echo/hello'),
        wsServer.get('/boom'),
        wsClient.get('/echo/goodbye'),
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
      wsServer.on.get('/', (req, res) {
        res.send(data: [1, 2, 3, 4, 5, 6, 7, 8, 9, 0]);
      });
      final result = await wsClient.get('/');
      expect(result.code, 200);
      expect(result.data, [1, 2, 3, 4, 5, 6, 7, 8, 9, 0]);
    });
    test('get data stream', () async {
      final file = File('test/assets/test1.txt');
      wsServer.on.get('/', (req, res) {
        res.send(data: file.openRead());
      });
      final result = await wsClient.get('/');
      expect(result.code, 100);
      expect(result.data, isA<Stream>());
      final fsData = (await file.openRead().toList()).expand((l) => l);
      final wsData = (await (result.data as Stream<List<int>>).toList()).expand((l) => l);
      expect(wsData, fsData);
    });
  });

  group('test puts', () {
    test('put String', () async {
      var data;
      wsServer.on.put('/string', (req, res) {
        data = req.data;
        res.send(code: 200);
      });
      final result = await wsClient.put('/string', 'test-string');
      expect(result.isSuccess, isTrue);
      expect(result.code, 200);
      expect(result.data, isNull);
      expect(data, 'test-string');
    });
    test('put data', () async {
      var data;
      wsServer.on.put('/', (req, res) {
        data = req.data;
        res.send(code: 200);
      });
      await wsClient.put('/', [1, 2, 3, 4, 5, 6, 7, 8, 9, 0]);
      expect(data, [1, 2, 3, 4, 5, 6, 7, 8, 9, 0]);
    });
    test('put / get data stream', () async {
      final file = File('test/assets/test1.txt');
      final fsData = (await file.openRead().toList()).expand((l) => l);
      final completer = Completer();
      wsServer.on.put('/', (req, res) async {
        res.send(code: 200);
        final result = await wsServer.get(req.data);
        final wsData = (await (result.data as Stream<List<int>>).toList()).expand((l) => l);
        completer.complete(wsData);
      });
      final path = '/asdfasdfasdf';
      wsClient.on.get(path, (req, res) {
        res.send(data: file.openRead());
      });
      final result = await wsClient.put('/', path);
      expect(result.code, 200);
      final wsData = await completer.future;
      expect(wsData, fsData);
    });
    // test('put data stream', () async {
    //   final file = File('test/assets/test1.txt');
    //   var completer = Completer();
    //   wsServer.on.put('/', (req, res) async {
    //     final wsData = (await req.stream.toList()).expand((l) => l);
    //     completer.complete(wsData);
    //   });
    //   final result = await wsClient.put('/', file.openRead());
    //   expect(result.code, 200);
    //   final fsData = (await file.openRead().toList()).expand((l) => l);
    //   final wsData = await completer.future;
    //   expect(wsData, fsData);
    // });
  });
}
