import 'dart:async';
import 'dart:html';

class WsSocket {

  final WebSocket ws;
  final _controller = StreamController();
  WsSocket(this.ws);

  static Future<WsSocket> connect(String url, [String authToken]) async {
    final auth = (authToken != null) ? ['authorization', 'TOKEN $authToken'] : <String>[];
    final ws = WebSocket(url, auth);
    final ready = Completer();
    ws.addEventListener('open', (event) => ready.complete());
    await ready;
    return WsSocket(ws);
  }

  StreamSubscription listen(onData, {onError, onDone}) {
    ws.addEventListener('message', _onMessage);
    return _controller.stream.listen(onData, onError: onError, onDone: () {
      ws.removeEventListener('message', _onMessage);
    });
  }

  Future<void> close([int code, String reason]) {
    ws.close(code, reason);
    return Future.value();
  }

  void add(data) => ws.send((data is List<int>) ? data : data.toString());

  void _onMessage(MessageEvent event) => _controller.add(event.data);
}
