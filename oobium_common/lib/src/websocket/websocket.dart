import 'dart:async';

import 'dart:io' if (dart.library.html) 'ws_html.dart' as ws;
import 'package:objectid/objectid.dart';
import 'package:oobium_common/oobium_common.dart';
import 'package:oobium_common/src/json.dart';
import 'package:oobium_common/src/router.extensions.dart';
import 'package:oobium_common/src/websocket/websocket_util.dart';

class ClientWebSocket extends WebSocket {
  ClientWebSocket(ws.WebSocket ws) : super(ws);
  static Future<ClientWebSocket> connect({String address, int port, String path, Map<String, dynamic> headers}) async {
    final url = 'ws://${address ?? '127.0.0.1'}:${port ?? 8080}${path ?? ''}';
    return ClientWebSocket(await ws.WebSocket.connect(url, headers: headers))..start();
  }
}

const _GET_PUT_KEY = '_get';
const _GET_PUT_PATH = '/UseSocketStatesInsteadOfThisHack';

class WebSocket {

  final ws.WebSocket _ws;
  final _done = Completer();
  StreamSubscription _wsSubscription;

  WebSocket(this._ws);

  Future<WsResult> get(String path, {bool retry = false}) {
    final message = WsMessage(type: 'REQ', id: ObjectId().hexString, method: 'GET', path: path);
    return retry ? _sendMessageWithRetries(message) : _sendMessage(message);
  }

  Future<WsResult> put(String path, dynamic data, {bool retry = false}) {
    final message = WsMessage(type: 'REQ', id: ObjectId().hexString, method: 'PUT', path: path, data: data);
    return retry ? _sendMessageWithRetries(message) : _sendMessage(message);
  }

  WsHandler _on;
  WsHandler get on => _on ??= WsHandler(this);

  Future<void> get done => _done.future;

  void start() {
    _wsSubscription ??= _ws.listen(_onData, onError: _onError, onDone: _onDone);
  }

  void pause() {
    _wsSubscription?.pause();
  }

  void resume() {
    _wsSubscription?.resume();
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

  Future<WsResult> _sendMessageWithRetries(WsMessage message) async {
    for(var i = 0; i < 10; i++) {
      await Future.delayed(Duration(milliseconds: i * 50));
      final result = (await _sendMessage(message));
      if(result.isSuccess) {
        return result;
      }
    }
    return WsResult(404, null);
  }

  Future<WsResult> _sendMessage(WsMessage message) {
    if(message.isRequest) {
      // 1. 'client' sends the request
      if(_completer == null) {
        _completer = Completer<WsResult>();
        if(message.method == 'PUT' && message.data is Stream) {
          on.get(_GET_PUT_PATH, (req, res) {
            on._getHandlers.remove(_GET_PUT_PATH);
            res.send(data: message.data);
          });
          _ws.add(message.copyWith(data: {_GET_PUT_KEY: _GET_PUT_PATH}).toString());
        } else {
          _ws.add(message.toString());
        }
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
    _ws.add(data);
  }

  void _receiveData(List<int> data) {
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
    final result = WsResult(code, data);
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
    _wsSubscription?.cancel();
    _wsSubscription = null;
    if(!_done.isCompleted) _done.complete();
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

  bool get isGet => method == 'GET';
  bool get isPut => method == 'PUT';
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
  toString() => '$type:$id:$method$path$_dataString';

  String get _dataString {
    return (data == null || data is Stream) ? '' : ' ${Json.encode(data)}';
  }
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
  final WebSocket _socket;
  WsResponse._(this._message, this._socket);

  bool _sent = false;

  void send({int code, dynamic data}) {
    _sent = true;
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
  WsResult(this.code, this.data);
  bool get isSuccess => (code >= 200) && (code < 300);
  bool get isNotSuccess => !isSuccess;

  @override
  String toString() => '$code($data)';
}
class WsStreamResult implements WsResult {
  final _controller = StreamController<List<int>>();
  int get code => 100;
  bool get isSuccess => true;
  bool get isNotSuccess => !isSuccess;
  Stream<List<int>> get data => _controller.stream;
}
class WsData {
  final dynamic _result;
  WsData(this._result);
  dynamic get value => _result.data;
  Stream<List<int>> get stream => _controller.stream;
  bool get isStream => _result is WsStreamResult;
  bool get isNotStream => !isStream;
  StreamController<List<int>> get _controller {
    if(_result is WsStreamResult) {
      return _result._controller;
    }
    return null;
  }
}

class WsHandler {

  final WebSocket _socket;
  final _getHandlers = <String, WsGetHandler>{};
  final _putHandlers = <String, WsPutHandler>{};

  WsHandler(this._socket);

  void _handleMessage(WsMessage message) {
    if(message.isGet) {
      _handleGet(message);
    } else {
      _handlePut(message);
    }
  }

  void _handleGet(WsMessage message) {
    final path = 'GET${message.path}';
    final routePath = _getHandlers.containsKey(path) ? path : path.findRouterPath(_getHandlers.keys);
    final handler = _getHandlers[routePath];
    if(handler != null) {
      final request = WsRequest._(message, routePath);
      final response = WsResponse._(message, _socket);
      try {
        Future.value(handler(request, response)).then((_) {
          if(!response._sent) response.send(code: 200);
        });
      } catch(error, stackTrace) {
        print('$error\n$stackTrace');
        response.send(code: 500);
      }
    } else {
      _socket._sendMessage(message.toResponse(404));
    }
  }

  void _handlePut(WsMessage message) {
    final path = 'PUT${message.path}';
    final routePath = _putHandlers.containsKey(path) ? path : path.findRouterPath(_putHandlers.keys);
    final handler = _putHandlers[routePath];
    if(handler != null) {
      try {
        final key = (message.data is Map) ? message.data[_GET_PUT_KEY] : null;
        if(key != null) {
          _socket.get(_GET_PUT_PATH).then((result) {
            final data = WsData(result);
            Future.value(handler(data)).then((_) {
              _socket._sendMessage(message.toResponse(200));
            });
          });
        } else {
          final data = WsData(WsResult(200, message.data));
          Future.value(handler(data)).then((_) {
            _socket._sendMessage(message.toResponse(200));
          });
        }
      } catch(error, stackTrace) {
        print('$error\n$stackTrace');
        _socket._sendMessage(message.toResponse(500));
      }
    } else {
      _socket._sendMessage(message.toResponse(404));
    }
  }

  WsSubscription get(String path, WsGetHandler handler) {
    _getHandlers['GET$path'] = handler;
    return WsSubscription(() => _getHandlers.remove('GET$path'));
  }
  WsSubscription put(String path, WsPutHandler handler) {
    _putHandlers['PUT$path'] = handler;
    return WsSubscription(() => _putHandlers.remove('PUT$path'));
  }
}
class WsSubscription {
  final Function _onCancel;
  WsSubscription(this._onCancel);
  void cancel() => _onCancel();
}
typedef WsGetHandler = FutureOr<void> Function(WsRequest request, WsResponse response);
typedef WsPutHandler = FutureOr<void> Function(WsData data);
