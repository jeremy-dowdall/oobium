import 'dart:async';
import 'dart:html';

import 'dart:typed_data';

class WsSocket {

  final WebSocket ws;
  WsSocket(this.ws);

  static Future<WsSocket> upgrade(HttpRequest request) => throw UnsupportedError('platform not supported');

  static Future<WsSocket> connect(String url, [String authToken]) async {
    final auth = (authToken != null) ? ['authorization', 'TOKEN $authToken'] : <String>[];
    final ws = WebSocket(url, auth);
    ws.binaryType = 'arraybuffer';
    await ws.onOpen.first;
    return WsSocket(ws);
  }

  StreamSubscription listen(onData, {onError, onDone}) => ws.onMessage.map(_decode).listen(onData, onError: onError, onDone: onDone);

  Future<void> close([int code, String reason]) {
    ws.close(code, reason);
    return ws.onClose.first;
  }

  void add(data) => ws.send(_encode(data));

  dynamic _encode(data) {
    if(data is List<int>) {
      return Uint8List.fromList(data).buffer;
    }
    return data.toString();
  }

  dynamic _decode(MessageEvent event) {
    if(event.data is ByteBuffer) {
      return event.data.asUint8List();
    }
    return event.data.toString();
  }
}
