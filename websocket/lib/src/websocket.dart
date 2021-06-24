import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:oobium_websocket/src/cancelable_completer.dart';
import 'package:oobium_websocket/src/router.extensions.dart';
import 'package:oobium_websocket/src/websocket/ws_socket.dart';

///
/// Get resource (String)
///   future = await client.get('/path')
///     client -> id:G/path
///     server <- id:G/path
///     server -> id:200 'data'
///     client <- id:200 'data'
///   future.complete(200, 'data')
///
/// Get data (Stream<List<int>>)
///   stream = client.getStream('/path')
///     client -> id:G/path
///     server <- id:G/path
///     server -> [1,2,3,4]
///     server -> [5,6,7,8]
///     client <- [1,2,3,4]
///   stream.event([1,2,3,4])
///     client <- [5,6,7,8]
///   stream.event([5,6,7,8])
///     server -> id:200
///     client <- id:200
///   stream.close
///
/// Put resource (String)
///   future = await client.put('/path', 'data')
///     client -> id:P/path 'data'
///     server <- id:P/path 'data'
///     server -> id:200
///     client <- id:200
///   future.complete(200)
///
/// Put data (Stream<List<int>>)
///   future = await client.putStream('/path', Stream<List<int>>)
///     client -> id:PS/path Stream<List<int>>
///     server <- id:PS/path
///     server -> id:100
///     client <- id:100
///     client -> List<int>
///     server <- List<int>
///     ...
///     client -> id:200
///     server <- id:200
///   future.complete(200)
///
class WebSocket {

  final String? name; // for debug / logging purposes
  WebSocket([this.name]);

  WsSocket? _ws;
  final _done = CancelableCompleter<void>();
  final _ready = CancelableCompleter<void>();
  StreamSubscription? _wsSubscription;
  WsResult? _closedResult;

  final _requests = Requests();
  final _streams = StreamQueue();

  final on = WsHandlers();

  Future<WebSocket> upgrade(httpRequest, {String Function(List<String> protocols)? protocol, bool autoStart = true}) async {
    assert(isNotStarted && isNotDone);
    _ws = await WsSocket.upgrade(httpRequest, protocol: protocol);
    if(autoStart == true) {
      start();
    }
    return this;
  }

  Future<WebSocket> connect({String address='127.0.0.1', int port=8080, String path='', List<String>? protocols, bool autoStart = true}) async {
    assert(isNotStarted && isNotDone);
    final url = 'ws://$address:$port$path';
    _ws = await WsSocket.connect(url, protocols: protocols);
    if(autoStart == true) {
      start();
    }
    return this;
  }

  Future<WsResult> get(String path) => _sendRequest(WsMessage.get(path));
  Stream<List<int>> getStream(String path) => _sendStreamRequest(WsMessage.getStream(path));
  Future<WsResult> put(String path, dynamic data) => _sendRequest(WsMessage.put(path, data));
  Future<WsResult> putStream(String path, Stream<List<int>> data) => _sendRequest(WsMessage.putStream(path, data));

  CancelableFuture<void> get ready => _ready.future;
  bool get isReady => _ready.isCompleted;
  bool get isNotReady => !isReady;

  CancelableFuture<void> get done => _done.future;
  bool get isDone => _done.isCompleted;
  bool get isNotDone => !isDone;

  bool get isStarted => _wsSubscription != null;
  bool get isNotStarted => !isStarted;

  bool get isConnected => isStarted && isNotDone;
  bool get isNotConnected => !isConnected;

  bool get isClosed => _closedResult != null;
  bool get isNotClosed => !isClosed;

  void start() {
    assert(_ws != null, 'attempted to start before native socket was attached');
    if(isNotStarted) {
      _wsSubscription = _ws!.listen(_onData, onError: _onError, onDone: _onDone);
      _ready.complete();
    }
  }

  void pause() {
    _wsSubscription?.pause();
  }

  void resume() {
    _wsSubscription?.resume();
  }

  Future<void> stop() async {
    await _wsSubscription?.cancel();
    _wsSubscription = null;
  }

  Future<void> close([int code=499, String reason='Client Closed Request']) async {
    await _ws?.close();
    _ws = null;
    final result = _closedResult = WsResult(code, reason);
    _requests.completeAll(result);
    _streams.closeAll();
    if(isNotDone) _done.complete();
  }

  Future<void> flush() async {
    await _requests.flush();
    await _streams.flush();
  }

  ///
  /// programmatic entry-point
  ///
  Future<WsResult> _sendRequest(WsMessage message) {
    if(isClosed) {
      return Future.value(_closedResult);
    }
    final future = _requests.add(message).future;
    _send(message);
    return future;
  }
  Stream<List<int>> _sendStreamRequest(WsMessage message) {
    final item = _streams.add(message);
    if(_streams.isReceiving(item)) {
      _send(message);
    }
    return item.controller.stream;
  }

  ///
  /// socket entry-point
  ///
  void _onMessage(String data) {
    final message = WsMessage.parse(data);
    switch(message.type) {
      case 'G':
      case 'P':
        _onRequest(message);
        break;
      case 'GS':
        _onGetStreamRequest(message);
        break;
      case 'PS':
        _onPutStreamRequest(message);
        break;
      case '100':
        final request = _requests[message];
        if(request != null) {
          (request.message.data as Stream<List<int>>).listen((data) => _send(data),
              onDone: () => _send(request.message.as('200')),
              onError: (e) => _send(request.message.as('500', e))
          );
        }
        break;
      case '200':
      case '404':
      case '500':
        if(_requests.complete(message) == false) {
          final next = _streams.close(message);
          if(next != null) {
            _send(next.message);
          }
        }
        break;
      default:
        throw 'unknown message type, ${message.type}, in $message';
    }
  }

  void _onRequest(WsMessage message) {
    final path = '${message.type}${message.path}';
    final routePath = on._handlers.containsKey(path) ? path : path.findRouterPath(on._handlers.keys);
    final handler = on._handlers[routePath];
    if(handler == null) {
      _send(message.as('404'));
    } else {
      final request = WsRequest._(message, routePath!, message.data);
      Future.value(handler(request))
        .then((result) {
          if(result is WsResult) {
            _send(message.as('${result.code}', result.data));
          } else {
            _send(message.as('200', result));
          }
        })
        .catchError((error, stackTrace) {
          _log('$error\n$stackTrace');
          _send(message.as('500', error));
        });
    }
  }
  void _onGetStreamRequest(WsMessage message) {
    assert(message.type == 'GS');
    final path = '${message.type}${message.path}';
    final routePath = on._getStreamHandlers.containsKey(path) ? path : path.findRouterPath(on._getStreamHandlers.keys);
    final handler = on._getStreamHandlers[routePath];
    if(handler == null) {
      _send(message.as('404'));
    } else {
      final request = WsRequest._(message, routePath!, message.data);
      Future.value(handler(request))
          .then((result) {
            result.listen((data) => _send(data),
                onDone: () => _send(message.as('200')),
                onError: (e) => _send(message.as('500', e))
            );
          })
          .catchError((e,s) {
            _log('$e\n$s');
            _send(message.as('500', e));
          });
    }
  }
  void _onPutStreamRequest(WsMessage message) {
    assert(message.type == 'PS');
    final path = '${message.type}${message.path}';
    final routePath = on._putStreamHandlers.containsKey(path) ? path : path.findRouterPath(on._putStreamHandlers.keys);
    final handler = on._putStreamHandlers[routePath];
    if(handler == null) {
      _send(message.as('404'));
    } else {
      final item = _streams.add(message);
      final request = WsStreamRequest._(message, routePath!, item.controller);
      Future.value(handler(request))
          .then((result) {
            if(result is WsResult) {
              _send(message.as('${result.code}', result.data));
            } else {
              _send(message.as('200', result));
            }
          })
          .catchError((e,s) {
            _log('$e\n$s');
            _send(message.as('500', e));
          });
      if(_streams.isReceiving(item)) {
        _send(item.message.as('100'));
      }
    }
  }

  void _onData(dynamic data) {
    // _log('onData: $data');
    if(data is String) {
      _onMessage(data);
    }
    if(data is List<int>) {
      _streams.onData(data);
    }
  }

  void _onError(Object error, StackTrace stackTrace) {
    _log('error: $error\n$stackTrace');
  }

  void _onDone() {
    close(444, 'Connection Closed Without Response');
  }

  T _send<T>(T data) {
    // _log('send: $data');
    if(isClosed) {
      _log('tried adding to a closed socket');
    } else {
      _ws!.add(data); // TODO json...
    }
    return data;
  }

  void _log(msg) => print('${DateTime.now().millisecondsSinceEpoch} ${(name == null) ? msg : '$name: $msg'}');
}

class StreamQueue {
  StreamItem? _receiving;
  final _items = <StreamItem>[];
  Completer? _flush;

  StreamItem get first => _items.first;

  StreamItem add(WsMessage message) {
    final item = StreamItem(message);
    _items.add(item);
    _receiving ??= item;
    return item;
  }

  bool isReceiving(StreamItem item) => _receiving == item;

  void onData(List<int> data) {
    // _log('data: $data');
    _items.first.controller.add(data);
  }

  StreamItem? close(WsMessage message) {
    // _log('close: $message');
    final item = _items.firstWhereOrNull((i) => i.message.id == message.id);
    if(item != null && _items.remove(item)) {
      item.controller.close().then((_) {
        if(_items.isEmpty) {
          _flush?.complete();
          _flush = null;
        }
      });
      if(_receiving == item && _items.isNotEmpty) {
        _receiving = _items.first;
        return _receiving;
      }
    }
    return null;
  }

  void closeAll() {
    _receiving = null;
    for(final item in _items) {
      item.controller.close();
    }
    _items.clear();
    _flush?.complete();
    _flush = null;
  }

  Future<void> flush() => _items.isEmpty
    ? Future.value()
    : (_flush = Completer()).future;
}

class StreamItem {
  final WsMessage message;
  final controller = StreamController<List<int>>();
  StreamItem(this.message);
}

class Requests {
  final _items = <String, RequestItem>{};
  Completer? _flush;

  RequestItem? operator [](WsMessage message) => _items[message.id];

  RequestItem add(WsMessage message) => _items[message.id] = RequestItem(message);

  bool complete(WsMessage message) {
    final item = _items.remove(message.id);
    if(item != null) {
      item.complete(message.toResult());
      if(_items.isEmpty) {
        _flush?.complete();
        _flush = null;
      }
      return true;
    }
    return false;
  }

  void completeAll(WsResult result) {
    for(final item in _items.values) {
      item.complete(result);
    }
    _items.clear();
    _flush?.complete();
    _flush = null;
  }

  Future<void> flush() => _items.isEmpty
    ? Future.value()
    : (_flush = Completer()).future;
}

class RequestItem {
  final WsMessage message;
  final _completer = Completer<WsResult>();
  RequestItem(this.message);
  Future<WsResult> get future => _completer.future;
  void complete(WsResult result) => _completer.complete(result);
}

class MessageId {
  final String value;
  MessageId._(this.value);
  factory MessageId() => MessageId._(next);

  @override
  String toString() => value;

  static String get current => '$_counter';
  static String get next => '${_counter = (_counter < double.maxFinite) ? _counter + 1 : 0}';
  static var _counter = -1;
}

class WsMessage {
  final String id;
  final String type;
  final String path;
  final data;
  WsMessage.get(this.path, [this.data]) : id = MessageId.next, type = 'G';
  WsMessage.put(this.path, [this.data]) : id = MessageId.next, type = 'P';
  WsMessage.getStream(this.path, [this.data]) : id = MessageId.next, type = 'GS';
  WsMessage.putStream(this.path, Stream<List<int>> data) : id = MessageId.next, type = 'PS', data = data;
  WsMessage._({
    required this.id,
    required this.type,
    this.path='',
    this.data
  });

  // <id>:<type>[/path][ {data}]
  factory WsMessage.parse(String str) {
    final match = _pattern.firstMatch(str);
    if(match != null) {
      return WsMessage._(
          id:   match.group(1)!,
          type: match.group(2)!,
          path: match.group(3) ?? '',
          data: _jsonDecode(match.group(5))
      );
    } else {
      throw FormatException('cannot parse message: $str');
    }
  }
  static final _pattern = RegExp(r'^(\d+):(\w+)([/\w]+)?( (.+))?$');
  static _jsonDecode(String? data) => (data != null) ? jsonDecode(data) : null;

  WsMessage as(String type, [data]) => WsMessage._(id: id, type: type, data: data);

  WsResult toResult() => WsResult(int.parse(type), data);

  @override
  toString() => '$id:$type$path$_dataString';

  String get _dataString {
    return (data == null || data is Stream<List<int>>) ? '' : ' ${jsonEncode(data)}';
  }
}

class WsRequest {
  final WsMessage _message;
  final String _routePath;
  final dynamic data;
  WsRequest._(this._message, this._routePath, this.data);

  operator [](String key) => params[key];

  String get method => _message.type;
  String get path => _message.path;

  Map<String, dynamic>? _params;
  Map<String, dynamic> get params => _params ??= '$method$path'.parseParams(_routePath);
}
class WsStreamRequest {
  final WsMessage _message;
  final String _routePath;
  final StreamController<List<int>> _controller;
  WsStreamRequest._(this._message, this._routePath, this._controller);

  Stream<List<int>> get stream => _controller.stream;

  operator [](String key) => params[key];

  String get method => _message.type;
  String get path => _message.path;

  Map<String, dynamic>? _params;
  Map<String, dynamic> get params => _params ??= '$method$path'.parseParams(_routePath);
}

class WsResult {
  final int code;
  final dynamic data;
  WsResult(this.code, [this.data]);
  bool get isSuccess => (code >= 200) && (code < 300);
  bool get isNotSuccess => !isSuccess;

  @override
  String toString() => '$code($data)';
}

class WsHandlers {

  final _handlers = <String, WsMessageHandler>{};
  final _getStreamHandlers = <String, WsGetStreamHandler>{};
  final _putStreamHandlers = <String, WsPutStreamHandler>{};

  WsSubscription get(String path, WsMessageHandler handler)  => _add('G', path, handler);
  WsSubscription put(String path, WsMessageHandler handler) => _add('P', path, handler);
  WsSubscription getStream(String path, WsGetStreamHandler handler) => _addGetStream(path, handler);
  WsSubscription putStream(String path, WsPutStreamHandler handler) => _addPutStream(path, handler);

  WsSubscription _add(String method, String path, WsMessageHandler handler) {
    final route = _checkedRoute(method, path, _handlers.keys);
    _handlers[route] = handler;
    return WsSubscription(() => _handlers.remove(route));
  }

  WsSubscription _addGetStream(String path, WsGetStreamHandler handler) {
    final route = _checkedRoute('GS', path, _getStreamHandlers.keys);
    _getStreamHandlers[route] = handler;
    return WsSubscription(() => _getStreamHandlers.remove(route));
  }

  WsSubscription _addPutStream(String path, WsPutStreamHandler handler) {
    final route = _checkedRoute('PS', path, _putStreamHandlers.keys);
    _putStreamHandlers[route] = handler;
    return WsSubscription(() => _putStreamHandlers.remove(route));
  }

  String _checkedRoute(String method, String path, Iterable<String> routes) {
    final route = '$method$path';
    final sa = route.verifiedSegments;
    for(var handlerRoute in routes) {
      if(sa.matches(handlerRoute.segments)) {
        throw 'duplicate route: $route';
      }
    }
    return route;
  }
}
class WsSubscription {
  final Function _onCancel;
  WsSubscription(this._onCancel);
  void cancel() => _onCancel();
}
typedef WsMessageHandler = FutureOr<dynamic> Function(WsRequest request);
typedef WsGetStreamHandler = FutureOr<Stream<List<int>>> Function(WsRequest request);
typedef WsPutStreamHandler = FutureOr<dynamic> Function(WsStreamRequest request);
