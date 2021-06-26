import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:oobium_websocket/src/cancelable_completer.dart';
import 'package:oobium_websocket/src/logging.dart';
import 'package:oobium_websocket/src/router.extensions.dart';
import 'package:oobium_websocket/src/websocket/ws_socket.dart';

final log = Logger('websocket');

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

  final String name; // for debug / logging purposes
  WebSocket([this.name='websocket']);

  WsSocket? _ws;
  late bool _upgraded; // is this the upgraded (or 'server') side
  final _done = CancelableCompleter<void>();
  final _ready = CancelableCompleter<void>();
  StreamSubscription? _wsSubscription;
  WsResult? _closedResult;

  final _requests = Requests();
  final _streams = StreamQueue();

  final on = WsHandlers();

  Future<WebSocket> upgrade(httpRequest, {String Function(List<String> protocols)? protocol, bool autoStart = true}) async {
    assert(isNotStarted && isNotDone);
    _upgraded = true;
    _ws = await WsSocket.upgrade(httpRequest, protocol: protocol);
    if(autoStart == true) {
      start();
    }
    return this;
  }

  Future<WebSocket> connect({String address='127.0.0.1', int port=8080, String path='', List<String>? protocols, bool autoStart = true}) async {
    assert(isNotStarted && isNotDone);
    _upgraded = false;
    final url = 'ws://$address:$port$path';
    _ws = await WsSocket.connect(url, protocols: protocols);
    if(autoStart == true) {
      start();
    }
    return this;
  }

  Future<WsResult> get(String path, [WsHandlers? on]) {
    return _wrap(WsMessage.get(_upgraded, path), on, (msg) => _sendRequest(msg));
  }
  Stream<List<int>> getStream(String path) {
    return _sendStreamRequest(WsMessage.getStream(_upgraded, path));
  }
  Future<WsResult> put(String path, dynamic data, [WsHandlers? on]) {
    return _wrap(WsMessage.put(_upgraded, path, data), on, (msg) => _sendRequest(msg));
  }
  Future<WsResult> putStream(String path, Stream<List<int>> data, [WsHandlers? on]) {
    return _wrap(WsMessage.putStream(_upgraded, path, data), on, (msg) => _sendRequest(msg));
  }

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
    _send(item);
    return item.controller.stream;
  }

  ///
  /// socket entry-point
  ///
  void _onMessage(String data) {
    final message = WsMessage.parse(data);
    switch(message.type) {
      case 'G':
        _onGetRequest(message);
        break;
      case 'P':
        _onPutRequest(message);
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
          // TODO make cancelable
          (request.message.data as Stream<List<int>>).listen(
              (data) {
                _send(data);
              },
              onDone: () {
                final message = request.message.as('200');
                _complete(message);
                _send(message);
              },
              onError: (e) {
                final message = request.message.as('500', e);
                _complete(message);
                _send(message);
              }
          );
        }
        break;
      case '200':
      case '404':
      case '500':
        _complete(message);
        break;
      default:
        throw 'unknown message type, ${message.type}, in $message';
    }
  }

  void _complete(WsMessage message) {
    _requests.complete(message);
    final next = _streams.close(message);
    if(next != null) {
      _send(next);
    }
  }

  void _onGetRequest(WsMessage message) {
    assert(message.type == 'G');
    final handler = on._find<Get>(message);
    if(handler == null) {
      _send(message.as('404'));
    } else {
      final request = WsRequest._(this, message, handler.path, message.data);
      Future.value(handler.impl(request))
          .then((result) {
            if(result is WsResult) {
              _send(message.as('${result.code}', result.data));
            } else {
              _send(message.as('200', result));
            }
          })
          .catchError((error, stackTrace) {
            log.warning('$name: $error\n$stackTrace');
            _send(message.as('500', error));
          });
    }
  }
  void _onGetStreamRequest(WsMessage message) {
    assert(message.type == 'GS');
    final handler = on._find<GetStream>(message);
    if(handler == null) {
      _send(message.as('404'));
    } else {
      final request = WsRequest._(this, message, handler.path, message.data);
      Future.value(handler.impl(request))
          .then((result) {
            result.listen((data) => _send(data),
                onDone: () => _send(message.as('200')),
                onError: (e) => _send(message.as('500', e))
            );
          })
          .catchError((e,s) {
            log.warning('$name: $e\n$s');
            _send(message.as('500', e));
          });
    }
  }
  void _onPutRequest(WsMessage message) {
    assert(message.type == 'P');
    final handler = on._find<Put>(message);
    if(handler == null) {
      _send(message.as('404'));
    } else {
      final request = WsRequest._(this, message, handler.path, message.data);
      Future.value(handler.impl(request))
          .then((result) {
            if(result is WsResult) {
              _send(message.as('${result.code}', result.data));
            } else {
              _send(message.as('200', result));
            }
          })
          .catchError((error, stackTrace) {
            log.warning('$name: $error\n$stackTrace');
            _send(message.as('500', error));
          });
    }
  }
  void _onPutStreamRequest(WsMessage message) {
    assert(message.type == 'PS');
    final handler = on._find<PutStream>(message);
    if(handler == null) {
      _send(message.as('404'));
    } else {
      final item = _streams.add(message);
      final request = WsStreamRequest._(this, message, handler.path, item.controller);
      Future.value(handler.impl(request))
          .then((result) {
            if(result != false) {
              _send(item);
            }
          })
          .catchError((e,s) {
            log.warning('$name: $e\n$s');
            _send(message.as('500', e));
          });
    }
  }

  void _onData(dynamic data) {
    if(data is String) {
      log.fine(() => '$name: rcv: $data');
      _onMessage(data);
    }
    if(data is List<int>) {
      log.fine(() => '$name: rcv: List<int>');
      _streams.onData(data);
    }
  }

  void _onError(Object error, StackTrace stackTrace) {
    log.error('$name: error: $error\n$stackTrace');
  }

  void _onDone() {
    close(444, 'Connection Closed Without Response');
  }

  void _send(data) {
    if(isClosed) {
      log.error('$name: tried adding to a closed socket');
      log.fine(() => '$name: snd: $data');
    }
    else if(data is StreamItem) {
      if(_streams.isReceiving(data)) {
        log.fine(() => '$name: snd: ${data.message(this)}');
        _ws!.add(data.message(this));
      } else {
        log.fine(() => '$name: snd: ${data.message(this)} - q');
      }
    }
    else {
      log.fine(() => '$name: snd: ${(data is List<int>) ? 'List<int>' : data}');
      _ws!.add(data); // TODO json... ?
    }
  }

  Future<WsResult> _wrap(WsMessage msg, WsHandlers? on, Future<WsResult> Function(WsMessage msg) f) {
    if(on != null) {
      msg = msg.onChannel();
      on.attach(this.on, msg.channel);
      return f(msg).then((result) {
        on.detach();
        return result;
      });
    } else {
      return f(msg);
    }
  }
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
    _items.first.controller.add(data);
  }

  StreamItem? close(WsMessage message) {
    final item = _items.firstWhereOrNull((i) => i.id == message.id);
    if(item != null && _items.remove(item)) {
      item.controller.close().then((_) {
        if(_items.isEmpty) {
          _flush?.complete();
          _flush = null;
        }
      });
      if(_receiving == item) {
        if(_items.isEmpty) {
          _receiving = null;
        } else {
          _receiving = _items.first;
        }
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
  final WsMessage _message;
  final controller = StreamController<List<int>>();
  StreamItem(this._message);
  String get id => _message.id;
  WsMessage message(WebSocket socket) {
    return (socket._upgraded == MessageId.isUpgraded(_message.id))
        ? _message
        : _message.as('100');
  }
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
  static var _counter = 1; // always > 0
  static String current(bool upgraded) => '$_counter${upgraded?0:1}';
  static String next(bool upgraded) {
    _counter = (_counter < double.maxFinite) ? _counter + 1 : 1;
    return current(upgraded);
  }
  static bool isUpgraded(String id) => id.endsWith('0');
}

class WsMessage {
  final String id;
  final String channel;
  final String type;
  final String path;
  final data;
  WsMessage.get(bool upgraded, this.path, {this.channel='0'}) : id = MessageId.next(upgraded), type = 'G', data = null;
  WsMessage.put(bool upgraded, this.path, this.data, {this.channel='0'}) : id = MessageId.next(upgraded), type = 'P';
  WsMessage.getStream(bool upgraded, this.path, {this.channel='0'}) : id = MessageId.next(upgraded), type = 'GS', data = null;
  WsMessage.putStream(bool upgraded, this.path, Stream<List<int>> data, {this.channel='0'}) : id = MessageId.next(upgraded), type = 'PS', data = data;
  WsMessage._({
    required this.id,
    required this.channel,
    required this.type,
    this.path='',
    this.data
  });

  // <id>:<channel>|<type>[/path][ {data}]
  factory WsMessage.parse(String str) {
    final match = _pattern.firstMatch(str);
    if(match != null) {
      return WsMessage._(
          id:      match.group(1)!,
          channel: match.group(2)!,
          type:    match.group(3)!,
          path:    match.group(4) ?? '',
          data:    _jsonDecode(match.group(6))
      );
    } else {
      throw FormatException('cannot parse message: $str');
    }
  }
  static final _pattern = RegExp(r'^(\d+):(\d+)\|(\w+)([/\w]+)?( (.+))?$');
  static _jsonDecode(String? data) => (data != null) ? jsonDecode(data) : null;

  WsMessage as(String type, [data]) {
    return WsMessage._(id: id, channel: channel, type: type, data: data);
  }

  WsMessage onChannel() {
    assert(channel == '0');
    return WsMessage._(id: id, channel: id, type: type, path: path, data: data);
  }

  WsResult toResult() => WsResult(int.parse(type), data);

  @override
  toString() => '$id:$channel|$type$path$_dataString';

  String get _dataString {
    return (data == null || data is Stream<List<int>>) ? '' : ' ${jsonEncode(data)}';
  }
}

class WsRequest {
  final WsRequestSocket socket;
  final WsMessage _message;
  final String _routePath;
  final dynamic data;
  WsRequest._(WebSocket socket, this._message, this._routePath, this.data) :
    socket = WsRequestSocket._(socket, _message.channel);

  operator [](String key) => params[key];

  String get path => _message.path;

  Map<String, dynamic>? _params;
  Map<String, dynamic> get params => _params ??= path.parseParams(_routePath);
}
class WsStreamRequest {
  final WebSocket socket;
  final WsMessage _message;
  final String _routePath;
  final StreamController<List<int>> _controller;
  WsStreamRequest._(this.socket, this._message, this._routePath, this._controller);

  Stream<List<int>> get stream => _controller.stream;

  operator [](String key) => params[key];

  String get path => _message.path;

  Map<String, dynamic>? _params;
  Map<String, dynamic> get params => _params ??= path.parseParams(_routePath);
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

class WsRequestSocket {
  final WebSocket _socket;
  final String _channel;
  WsRequestSocket._(this._socket, this._channel);
  Future<WsResult> get(String path) => _socket._sendRequest(WsMessage.get(_socket._upgraded, path, channel: _channel));
  Stream<List<int>> getStream(String path) => _socket._sendStreamRequest(WsMessage.getStream(_socket._upgraded, path, channel: _channel));
  Future<WsResult> put(String path, dynamic data) => _socket._sendRequest(WsMessage.put(_socket._upgraded, path, data, channel: _channel));
  Future<WsResult> putStream(String path, Stream<List<int>> data) => _socket._sendRequest(WsMessage.putStream(_socket._upgraded, path, data, channel: _channel));
  Future<void> flush() => _socket.flush();
}

class WsHandlers {

  var _channel = '0';
  WsHandlers? _parent;

  final _children = <WsHandlers>[];
  final _handlers = <Type, Map<String, dynamic>>{};

  void attach(WsHandlers parent, String channel) {
    if(_parent != parent) {
      detach();
      _channel = channel;
      _parent = parent;
      parent._children.add(this);
    }
  }

  void clear() {
    _handlers.clear();
  }

  void detach() {
    _parent?._children.remove(this);
    _parent = null;
    _channel = '0';
  }

  void dispose() {
    for(final child in _children) {
      child.dispose();
    }
    _handlers.clear();
    detach();
  }

  bool get isEmpty => _handlers.isEmpty;
  bool get isNotEmpty => !isEmpty;

  WsSubscription get(String path, WsGetHandler handler) => _add<Get>(path, handler);
  WsSubscription put(String path, WsPutHandler handler) => _add<Put>(path, handler);
  WsSubscription getStream(String path, WsGetStreamHandler handler) => _add<GetStream>(path, handler);
  WsSubscription putStream(String path, WsPutStreamHandler handler) => _add<PutStream>(path, handler);

  WsSubscription _add<T>(String path, impl) {
    _check<T>(path);
    _handlers.putIfAbsent(T, () => {})[path] = impl;
    return WsSubscription(() {
      _handlers[T]?.remove(path);
      if(_handlers[T]?.isEmpty == true) {
        _handlers.remove(T);
      }
    });
  }

  void _check<T>(String path) {
    final routes = _handlers[T]?.keys;
    if(routes != null) {
      final sa = path.verifiedSegments;
      for(var handlerRoute in routes) {
        if(sa.matches(handlerRoute.segments)) {
          throw 'duplicate route: $T$path';
        }
      }
    }
  }

  T? _find<T>(WsMessage message) {
    for(final child in _children) {
      if(child._channel == message.channel) {
        return child._find<T>(message);
      }
    }
    final route = message.path;
    final handlers = _handlers[T];
    if(handlers != null) {
      final routePath = handlers.containsKey(route) ? route : route.findRouterPath(handlers.keys);
      if(routePath != null) {
        final handler = handlers[routePath];
        if(handler != null) {
          switch(T) {
            case Get:       return Get(routePath, handler) as T;
            case GetStream: return GetStream(routePath, handler) as T;
            case Put:       return Put(routePath, handler) as T;
            case PutStream: return PutStream(routePath, handler) as T;
            default:
              throw 'handler type $T not implemented';
          }
        }
      }
    }
    return null;
  }
}
class WsSubscription {
  final Function _onCancel;
  WsSubscription(this._onCancel);
  void cancel() => _onCancel();
}
typedef WsGetHandler = FutureOr<dynamic> Function(WsRequest request);
typedef WsPutHandler = FutureOr<dynamic> Function(WsRequest request);
typedef WsGetStreamHandler = FutureOr<Stream<List<int>>> Function(WsRequest request);
typedef WsPutStreamHandler = FutureOr<dynamic> Function(WsStreamRequest request);

class Get {
  final String path;
  final WsGetHandler impl;
  Get(this.path, this.impl);
  @override toString() => 'Get$path';
}
class GetStream {
  final String path;
  final WsGetStreamHandler impl;
  GetStream(this.path, this.impl);
  @override toString() => 'GetStream$path';
}
class Put {
  final String path;
  final WsPutHandler impl;
  Put(this.path, this.impl);
  @override toString() => 'Put$path';
}
class PutStream {
  final String path;
  final WsPutStreamHandler impl;
  PutStream(this.path, this.impl);
  @override toString() => 'PutStream$path';
}
