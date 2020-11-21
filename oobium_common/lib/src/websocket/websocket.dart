import 'dart:async';

import 'dart:io' if (dart.library.html) 'ws_html.dart';
import 'package:objectid/objectid.dart';
import 'package:oobium_common/oobium_common.dart';
import 'package:oobium_common/src/json.dart';
import 'package:oobium_common/src/router.extensions.dart';
import 'package:oobium_common/src/websocket/websocket_util.dart';

class ClientWebSocket extends BaseWebSocket {
  ClientWebSocket(WebSocket ws) : super(ws);
  static Future<ClientWebSocket> connect({String address, int port, String path, Map<String, dynamic> headers}) async {
    final url = 'ws://${address ?? '127.0.0.1'}:${port ?? 8080}${path ?? ''}';
    return ClientWebSocket(await WebSocket.connect(url, headers: headers));
  }
}

abstract class BaseWebSocket {

  final WebSocket _ws;
  StreamSubscription _wsSubscription;

  BaseWebSocket(this._ws);

  Future<WsResult> get(String path) {
    return _sendMessage(WsMessage(type: 'REQ', id: ObjectId().hexString, method: 'GET', path: path));
  }

  Future<WsResult> put(String path, dynamic data) {
    return _sendMessage(WsMessage(type: 'REQ', id: ObjectId().hexString, method: 'PUT', path: path, data: data));
  }

  WsHandler _on;
  WsHandler get on => _on ??= WsHandler(this);

  void start() {
    _wsSubscription ??= _ws.listen(_onData, onError: _onError, onDone: _onDone);
  }

  void pause() {
    _wsSubscription?.pause();
  }

  void stop() {
    _wsSubscription?.cancel();
    _wsSubscription = null;
  }

  void close([int code, String reason]) {
    stop();
    _ws.close(code, reason);
  }

  WsStreamResult _result;
  Completer<WsResult> _completer;

  Future<WsResult> _sendMessage(WsMessage message) {
    print('send message ${message.type}');
    if(message.isRequest) {
      // 1. 'client' sends the request
      if(_completer == null) {
        _completer = Completer<WsResult>();
        _ws.add(message.toString());
        return _completer.future;
      } else {
        return _completer.future.then((_) => _sendMessage(message));
      }
    } else {
      // 3. 'server' send the response
      _ws.add(message.toString());
      return Future.value(null);
    }
  }

  void _receiveMessage(WsMessage message) {
    print('receive message ${message.type}');
    if(message.isRequest) {
      // 2. 'server' receives the request
      on._handleMessage(message);
    } else {
      // 4. 'client' receives the response (and completes #1 with a result)
      if(message.type == '100') {
        _result = WsStreamResult();
        _completer.complete(_result);
        _completer = Completer<WsResult>();
      } else {
        final success = _complete(int.parse(message.type), message.data);
        if(success) _result?._controller?.close();
        else _result?._controller?.addError(message.data);
        _result = null;
      }
    }
  }

  void _sendData(List<int> data) {
    print('send data');
    _ws.add(data);
  }

  void _receiveData(List<int> data) {
    print('receive data');
    if(_result != null) {
      _result._controller.add(data);
    }
    else if(_completer != null) {
      _complete(200, data);
    }
    else {
      throw Exception('received unexpected data');
    }
  }

  bool _complete(int code, data) {
    final result = WsResult._(code, data);
    _completer.complete(result);
    _completer = null;
    return result.isSuccess;
  }

  void _onData(dynamic data) {
    if(data is String) {
      _receiveMessage(WsMessage.parse(data));
    }
    if(data is List<int>) {
      _receiveData(data);
    }
  }
  void _onError(Object error, StackTrace stackTrace) {
    print('error: $error\n$stackTrace');
  }
  void _onDone() {
    // TODO necessary?
    _wsSubscription?.cancel();
    _wsSubscription = null;
  }
}

class WsMessage {
  final String type;
  final String id;
  final String method;
  final String path;
  final dynamic data;
  WsMessage({this.type, this.id, this.method, this.path, this.data});

  factory WsMessage.parse(String data) {
    final i0 = data.indexOf(':');
    final i1 = data.indexOf(':', i0 + 1);
    final i2 = data.indexOf('/', i1 + 1);
    final i3 = data.indexOf(' ', i2 + 1);
    return WsMessage(
      type: data.substring(0, i0),
      id: data.substring(i0 + 1, i1),
      method: data.substring(i1 + 1, i2),
      path: data.substring(i2, (i3 != -1) ? i3 : null),
      data: (i3 != -1) ? Json.decode(data.substring(i3 + 1)) : null
    );
  }

  WsMessage copyWith({String type, String id, String method, String path, dynamic data}) => WsMessage(
    type: type ?? this.type, id: id ?? this.id, method: method ?? this.method, path: path ?? this.path,
    data: data // data is NOT automatically copied over
  );

  bool get isRequest => type == 'REQ';
  bool get isNotRequest => !isRequest;
  bool get isResponse => isNotRequest;
  bool get isNotResponse => isRequest;

  WsMessage toResponse(int code, [dynamic data]) => WsMessage(
    type: (code ?? 200).toString(),
    id: id,
    method: method,
    path: path,
    data: data
  );

  WsMessage toStreamResponse() => copyWith(type: '100');
  WsMessage toDone() => copyWith(type: '200');
  WsMessage toError(Object error) => copyWith(type: '500', data: error);

  @override
  toString() => '$type:$id:$method$path${(data != null) ? ' ${Json.encode(data)}' : ''}';
}

class WsRequest {
  final WsMessage _message;
  final String _routePath;
  WsRequest._(this._message, this._routePath);

  String get method => _message.method;
  String get path => _message.path;
  dynamic get data => _message.data;

  Map<String, dynamic> _params;
  Map<String, dynamic> get params => _params ??= '$method$path'.parseParams(_routePath);
}

class WsResponse {

  final WsMessage _message;
  final BaseWebSocket _socket;
  WsResponse._(this._message, this._socket);

  void send({int code, dynamic data}) {
    if(data is List<int>) {
      _socket._sendData(data);
    }
    else if(data is Stream) {
      _socket._sendMessage(_message.toStreamResponse());
      data.listen(
        (event) => _socket._sendData(event),
        onDone: () => _socket._sendMessage(_message.toDone()),
        onError: (e) => _socket._sendMessage(_message.toError(e))
      );
    }
    else {
      _socket._sendMessage(_message.toResponse(code, data));
    }
  }
}

class WsResult {
  final int code;
  final dynamic data;
  WsResult._(this.code, this.data);
  bool get isSuccess => (code >= 200) && (code < 300);
  bool get isNotSuccess => !isSuccess;
}
class WsStreamResult implements WsResult {
  final _controller = StreamController<List<int>>();
  int get code => 100;
  bool get isSuccess => true;
  bool get isNotSuccess => !isSuccess;
  Stream<List<int>> get data => _controller.stream;
}

class WsHandler {

  final BaseWebSocket _socket;
  final _handlers = <String, WsRequestHandler>{};

  WsHandler(this._socket);

  void _handleMessage(WsMessage message) {
    final path = '${message.method}${message.path}';
    final routePath = _handlers.containsKey(path) ? path : path.findRouterPath(_handlers.keys);
    final handler = _handlers[routePath];
    print('WS$path');
    if(handler != null) {
      final request = WsRequest._(message, routePath);
      final response = WsResponse._(message, _socket);
      try {
        handler(request, response);
      } catch(error, stackTrace) {
        print('$error\n$stackTrace');
        response.send(code: 500);
      }
    } else {
      _socket._sendMessage(message.toResponse(404));
    }
    return null;
  }

  void get(String path, WsRequestHandler handler) {
    _handlers['GET$path'] = handler;
  }
  void put(String path, WsRequestHandler handler) {
    _handlers['PUT$path'] = handler;
  }
}
typedef WsRequestHandler = FutureOr<void> Function(WsRequest request, WsResponse response);
