import 'dart:async';
import 'dart:io';

class WsSocket {

  final WebSocket ws;
  WsSocket(this.ws);

  static Future<WsSocket> upgrade(HttpRequest request) async {
    return WsSocket(await WebSocketTransformer.upgrade(request));
  }

  static Future<WsSocket> connect(String url, [String authToken]) async {
    final auth = (authToken != null) ? {'authorization': 'TOKEN $authToken'} : null;
    return WsSocket(await WebSocket.connect(url, headers: auth));
  }

  StreamSubscription listen(onData, {onError, onDone}) => ws.listen(onData, onError: onError, onDone: onDone);

  Future<void> close([int code, String reason]) => ws.close(code, reason);

  void add(data) => ws.add((data is List<int>) ? data : data.toString());
}
