import 'dart:async';
import 'dart:io';

import 'package:mockito/mockito.dart';
import 'package:oobium_server/src/server.dart';
import 'package:oobium_server/src/websocket/websocket.dart';
import 'package:test/test.dart';

void main() {
  group('test handler', () {
    test('test something', () {
      final ws = MockSocket();
      final socket = ServerWebSocket(ws);
      final handler = TestHandler();
      socket.addHandler(handler);
      socket.start();
      socket.addMessage(TestMessage());
    });
  });
}

class MockSocket extends Mock implements WebSocket {
  final controller = StreamController();
  MockSocket() {
    when(add(any)).thenAnswer((inv) {
      controller.add(inv.positionalArguments[0]);
    });
    when(listen(any, onError: anyNamed('onError'), onDone: anyNamed('onDone'))).thenAnswer((inv) {
      return controller.stream.listen(inv.positionalArguments[0], onError: inv.namedArguments[#onError], onDone: inv.namedArguments[#onDone]);
    });
  }
}
class MockHandler extends Mock implements TaskHandler { }
class MockMessage extends Mock implements WebSocketMessage { }

class TestHandler extends TaskHandler {

  @override
  void registerMessageBuilders() {
    register<TestMessage>((data) => TestMessage(data));
  }

  @override
  Future<WebSocketMessage> onMessage(WebSocketMessage message) async {
    print(message.socketData);
    return Done();
  }

  @override
  Future<WebSocketMessage> onData(List<int> data) async {
    print(data);
    return Done();
  }

}
class TestMessage extends WebSocketMessage {
  TestMessage([Map data]) : super(data);
}