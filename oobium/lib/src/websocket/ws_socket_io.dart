import 'dart:async';
import 'dart:io';

class WsSocket {

  final WebSocket ws;
  WsSocket(this.ws);

  static Future<WsSocket> upgrade(HttpRequest request, {String Function(List<String> protocols)? protocol}) async {
    return WsSocket(await WebSocketTransformer.upgrade(request, protocolSelector: protocol));
  }

  static Future<WsSocket> connect(String url, {List<String>? protocols}) async {
    return WsSocket(await WebSocket.connect(url, protocols: protocols));
  }

  StreamSubscription listen(onData, {onError, onDone}) => ws.listen(onData, onError: onError, onDone: onDone);

  Future<void> close([int? code, String? reason]) => ws.close(code, reason);

  void add(data) => ws.add((data is List<int>) ? data : data.toString());
}
