import 'dart:async';
import 'dart:html';

class WsSocket {

  final WebSocket ws;
  final _controller = StreamController();
  WsSocket(this.ws);

  static Future<WsSocket> connect(String url, [String authToken]) async {
    final auth = (authToken != null) ? ['authorization', 'TOKEN $authToken'] : <String>[];
    final ws = WebSocket(url, auth);
    await ws.onOpen.first;
    return WsSocket(ws);
  }

  StreamSubscription listen(onData, {onError, onDone}) {
    final handler = (event) => _controller.add(event.data);
    ws.addEventListener('message', handler);
    return _controller.stream.listen(onData, onError: onError, onDone: () {
      ws.removeEventListener('message', handler);
    });
  }

  Future<void> close([int code, String reason]) {
    ws.close(code, reason);
    return Future.value();
  }

  void add(data) => ws.send((data is List<int>) ? data : data.toString());
}
