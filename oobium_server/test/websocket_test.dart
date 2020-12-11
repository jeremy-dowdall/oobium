import 'dart:async';
import 'dart:io';

import 'package:oobium_common/oobium_common.dart';
import 'package:oobium_common_test/oobium_common_test.dart';
import 'package:oobium_server/src/server.dart';
import 'package:test/test.dart';

Future<void> main() async {
  final wsServer = await TestIsolate.start(TestServer());

  ClientWebSocket wsClient;

  setUp(() async {
    wsClient?.close();
    wsClient = (await ClientWebSocket.connect(address: '127.0.0.1', port: 8001))..start();
  });
  tearDown(() async {
    wsClient?.close();
    wsClient = null;
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
      final result = await wsClient.get('/echo/hello');
      expect(result.code, 200);
      expect(result.data, 'hello');
    });
    test('multiple gets, client (url params) and server (404)', () async {
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
      final result = await wsClient.get('/data');
      expect(result.code, 200);
      expect(result.data, [1, 2, 3, 4, 5, 6, 7, 8, 9, 0]);
    });
    test('get data stream', () async {
      final result = await wsClient.get('/stream');
      expect(result.code, 100);
      expect(result.data, isA<Stream>());
      final fsData = (await File('test/assets/test1.txt').openRead().toList()).expand((l) => l);
      final wsData = (await (result.data as Stream<List<int>>).toList()).expand((l) => l);
      expect(wsData, fsData);
    });
  });

  group('test puts', () {
    test('put String', () async {
      final result = await wsClient.put('/data', 'test-string');
      expect(result.isSuccess, isTrue);
      expect(result.code, 200);
      expect(result.data, isNull);
      expect(await wsServer.data, 'test-string');
    });
    test('put data', () async {
      await wsClient.put('/data', [1, 2, 3, 4, 5, 6, 7, 8, 9, 0]);
      expect(await wsServer.data, [1, 2, 3, 4, 5, 6, 7, 8, 9, 0]);
    });
    test('put data stream', () async {
      final file = File('test/assets/test1.txt');
      final result = await wsClient.put('/stream', file.openRead());
      expect(result.code, 200);
      final fsData = (await file.openRead().toList()).expand((l) => l);
      final wsData = await wsServer.data;
      expect(wsData, fsData);
    });
  });

  // group('test x-client', () {
  //   test('put String', () async {
  //     wsServer.on.put('/register', (data) {
  //
  //     });
  //     final result = await wsClient.put('/string', 'test-string');
  //     expect(result.isSuccess, isTrue);
  //     expect(result.code, 200);
  //   });
  // });
}

class TestServer extends TestIsolate {

  Server server;
  ServerWebSocket wsServer;
  var wsData;

  @override
  Future<void> onStart() {
    server = Server(address: '127.0.0.1', port: 8001);
    server.get('/', [websocket((socket) {
      print('client websocket connected');
      wsServer = socket;
      wsServer.on.get('/echo/<msg>', (req, res) {
        res.send(data: req.params['msg']);
      });
      wsServer.on.get('/data', (req, res) {
        res.send(data: [1, 2, 3, 4, 5, 6, 7, 8, 9, 0]);
      });
      wsServer.on.get('/stream', (req, res) {
        res.send(data: File('test/assets/test1.txt').openRead());
      });
      wsServer.on.put('/data', (req, res) {
        wsData = req.data.value;
        print('data received: $wsData');
      });
      wsServer.on.put('/stream', (req, res) async {
        final completer = Completer<List<int>>();
        wsData = completer.future;
        final d = (await req.data.stream.toList()).expand((l) => l).toList();
        completer.complete(d);
      });
    })]);
    return server.start();
  }

  @override
  Future<void> onStop() {
    return server.stop();
  }

  @override
  FutureOr onMessage(String path, data) {
    if(path == 'getData') {
      return wsData;
    }
    if(path == 'get') {
      return wsServer.get(data);
    }
  }

  Future<WsResult> get(String path) async => (await send('get', path)) as WsResult;
  Future<dynamic> get data async => send('getData');
}

// class ServerIsolate {
//   Isolate isolate;
//   SendPort sendPort;
//
//   Future<WsResult> get(String path) async {
//     final port = ReceivePort();
//     sendPort.send(['get', path, port.sendPort]);
//     return (await port.first) as WsResult;
//   }
//
//   Future<dynamic> get data {
//     final port = ReceivePort();
//     sendPort.send(['getData', port.sendPort]);
//     return port.first;
//   }
//
//   Future<void> start() async {
//     final receivePort = ReceivePort();
//     isolate = await Isolate.spawn(_init, receivePort.sendPort);
//     sendPort = await receivePort.first;
//   }
//
//   static Future<void> _init(SendPort sendPort) async {
//     final port = ReceivePort();
//     sendPort.send(port.sendPort);
//
//     final server = Server(address: '127.0.0.1', port: 8001);
//     ServerWebSocket wsServer;
//     var wsData;
//     server.get('/', [websocket((socket) {
//       print('client websocket connected');
//       wsServer = socket;
//       wsServer.on.get('/echo/<msg>', (req, res) {
//         res.send(data: req.params['msg']);
//       });
//       wsServer.on.get('/data', (req, res) {
//         res.send(data: [1, 2, 3, 4, 5, 6, 7, 8, 9, 0]);
//       });
//       wsServer.on.get('/stream', (req, res) {
//         res.send(data: File('test/assets/test1.txt').openRead());
//       });
//       wsServer.on.put('/data', (data) {
//         wsData = data.value;
//         print('data received: $wsData');
//       });
//       wsServer.on.put('/stream', (data) async {
//         final completer = Completer<List<int>>();
//         wsData = completer.future;
//         final d = (await data.stream.toList()).expand((l) => l).toList();
//         completer.complete(d);
//       });
//     })]);
//     await server.start();
//
//     await for(var msg in port) {
//       if(msg[0] == 'getData') {
//         (msg[1] as SendPort).send(await wsData);
//       }
//       if(msg[0] == 'get') {
//         (msg[2] as SendPort).send(await wsServer.get(msg[1]));
//       }
//     }
//   }
// }
