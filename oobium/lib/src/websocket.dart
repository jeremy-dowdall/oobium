import 'dart:async';

import 'package:objectid/objectid.dart';
import 'package:oobium/src/json.dart';
import 'package:oobium/src/router.extensions.dart';
import 'package:oobium/src/websocket/ws_socket.dart';

export 'package:oobium/src/websocket/ws_file.dart';

const _GET_PUT_KEY = '_get';
const _GET_PUT_PATH = '/UseSocketStatesInsteadOfThisHack';

class WebSocket {

  WsSocket _ws;
  Completer _ready = Completer();
  Completer _done = Completer();
  StreamSubscription _wsSubscription;

  Future<WebSocket> upgrade(httpRequest, {String Function(List<String> protocols) protocol, bool autoStart = true}) async {
    await close();
    _ws = await WsSocket.upgrade(httpRequest, protocol: protocol);
    if(autoStart == true) {
      start();
    }
    return this;
  }
  Future<WebSocket> connect({String address, int port, String path, List<String> protocols, bool autoStart = true}) async {
    await close();
    final url = 'ws://${address ?? '127.0.0.1'}:${port ?? 8080}${path ?? ''}';
    _ws = await WsSocket.connect(url, protocols: protocols);
    if(autoStart == true) {
      start();
    }
    return this;
  }

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

  Future<void> get ready => _ready.future;

  Future<void> get done => _done.future;
  bool get isDone => _done.isCompleted;
  bool get isNotDone => !isDone;

  bool get isStarted => _wsSubscription != null;
  bool get isNotStarted => !isStarted;

  void start() {
    assert(_ws != null, 'attempted to start before native socket was attached');
    if(isNotStarted) {
      _wsSubscription = _ws.listen(_onData, onError: _onError, onDone: _onDone);
      _ready.complete();
    }
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

  Future<void> close([int code, String reason]) async {
    stop();
    await _ws?.close(code, reason);
    _ws = null;
    _ready = Completer();
    _done = Completer();
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
    assert(_ws != null, 'cannot send message: native socket not attached');
    if(message.isRequest) {
      // 1. 'client' sends the request
      if(_completer == null) {
        _completer = Completer<WsResult>();
        if(message.method == 'PUT' && message.data is Stream<List<int>>) {
          on.get(_GET_PUT_PATH, (req, res) {
            on._handlers.remove(_GET_PUT_PATH);
            res.send(data: message.data);
          });
          _ws.add(message.copyWith(data: {_GET_PUT_KEY: _GET_PUT_PATH}));
        } else {
          _ws.add(message);
        }
        return _completer.future;
      } else {
        return _completer.future.then((_) => _sendMessage(message));
      }
    } else {
      // 3. 'server' send the response
      _ws.add(message);
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
    assert(_ws != null, 'cannot send data: native socket not attached');
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
    return (data == null || data is Stream<List<int>>) ? '' : ' ${Json.encode(data)}';
  }
}

class WsRequest {
  final WsMessage _message;
  final String _routePath;
  final WsData data;
  WsRequest._(this._message, this._routePath, this.data);

  operator [](String key) => params[key];

  String get method => _message.method;
  String get path => _message.path;

  Map<String, dynamic> _params;
  Map<String, dynamic> get params => _params ??= '$method$path'.parseParams(_routePath);
}

class WsResponse {

  final WebSocket _socket;
  final WsMessage _message;
  WsResponse._(this._socket, this._message);

  bool _sent = false;

  void send({int code, dynamic data}) {
    _sent = true;
    if(data is List<int>) {
      _socket._sendData(data);
    }
    else if(data is Stream<List<int>>) {
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
  WsData(WsResult result) : _result = result;
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
  final _handlers = <String, WsMessageHandler>{};

  WsHandler(this._socket);

  WsSubscription get(String path, WsMessageHandler handler) {
    _handlers['GET$path'] = handler;
    return WsSubscription(() => _handlers.remove('GET$path'));
  }

  WsSubscription put(String path, WsMessageHandler handler) {
    _handlers['PUT$path'] = handler;
    return WsSubscription(() => _handlers.remove('PUT$path'));
  }

  Future<void> _handleMessage(WsMessage message) async {
    final path = '${message.method}${message.path}';
    final routePath = _handlers.containsKey(path) ? path : path.findRouterPath(_handlers.keys);
    final handler = _handlers[routePath];
    if(handler != null) {
      try {
        final request = WsRequest._(message, routePath, await _getData(message));
        final response = WsResponse._(_socket, message);
        await handler(request, response);
        if(!response._sent) response.send(code: 200);
      } catch(error, stackTrace) {
        print('$error\n$stackTrace');
        _socket._sendMessage(message.toResponse(500));
      }
    } else {
      _socket._sendMessage(message.toResponse(404));
    }
  }

  Future<WsData> _getData(WsMessage message) async {
    final key = (message.isPut && message.data is Map) ? message.data[_GET_PUT_KEY] : null;
    if(key != null) {
      return WsData(await _socket.get(_GET_PUT_PATH));
    }
    return WsData(WsResult(200, message.data));
  }
}
class WsSubscription {
  final Function _onCancel;
  WsSubscription(this._onCancel);
  void cancel() => _onCancel();
}
typedef WsMessageHandler = FutureOr<void> Function(WsRequest request, WsResponse response);
