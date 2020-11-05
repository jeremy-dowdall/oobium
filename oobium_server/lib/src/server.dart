import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:oobium_common/oobium_common.dart';
import 'package:oobium_server/oobium_server.dart';
import 'package:oobium_server/src/auth/validator.dart';
import 'package:oobium_server/src/html/html.dart';
import 'package:oobium_server/src/websocket/websocket.dart';
import 'package:oobium_server/src/utils.dart';
import 'package:oobium_server/src/server_settings.dart';

class Server {

  final ServerSettings settings;
  final _handlers = <String, List<RequestHandler>>{};
  final _loggers = <String, Logger>{};
  Server([ServerSettings settings]) : settings = settings ?? ServerSettings();

  Logger _logger = Logger();
  Logger get logger => _logger;
  set logger(Logger value) {
    assert(logger != null, 'logger must not be null');
    _logger = value;
  }

  void get(String path, List<RequestHandler> handlers, {Logger logger}) => _add('GET', path, handlers, logger: logger);
  void head(String path, List<RequestHandler> handlers, {Logger logger}) => _add('HEAD', path, handlers, logger: logger);
  void options(String path, List<RequestHandler> handlers, {Logger logger}) => _add('OPTIONS', path, handlers, logger: logger);
  void patch(String path, List<RequestHandler> handlers, {Logger logger}) => _add('PATCH', path, handlers, logger: logger);
  void post(String path, List<RequestHandler> handlers, {Logger logger}) => _add('POST', path, handlers, logger: logger);
  void put(String path, List<RequestHandler> handlers, {Logger logger}) => _add('PUT', path, handlers, logger: logger);
  void delete(String path, List<RequestHandler> handlers, {Logger logger}) => _add('DELETE', path, handlers, logger: logger);

  void static(String directoryPath, {String as = '', String Function(String path) pathBuilder, Logger logger, optional = false}) {
    assert(directoryPath != null || optional, 'directoryPath cannot be null, unless optional is true');
    if(directoryPath == null) {
      print('directory not specified... skipping.');
      return;
    }
    final directory = Directory(directoryPath);
    final exists = directory.existsSync();
    assert(exists || optional, '${directory.absolute} not found. Directory must exist unless optional is true');
    if(exists) {
      directory.listSync(recursive: true).whereType<File>().map((f) => f.path).forEach((filepath) {
        final basePath = filepath.substring(directoryPath.length);
        final builtPath = (pathBuilder != null) ? pathBuilder(basePath) : '$as/$basePath';
        final routePath = builtPath.replaceAll(RegExp(r'/+'), '/');
        get(routePath, [(req, res) => res.sendFile(File(filepath))], logger: logger);
        if(routePath.endsWith('index.html')) {
          final impliedPath = routePath.substring(0, routePath.length - 10);
          get(impliedPath, [(req, res) => res.sendFile(File(filepath))], logger: logger);
        }
      });
    } else {
      print('${directory.absolute} not found... skipping.');
    }
  }

  Future<void> start() async {
    var server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8080);
    print('Listening on http://${server.address.address}:${server.port}/');

    await for(HttpRequest request in server) {
      await _handle(request);
    }
  }

  List<RequestHandler> get _notFoundHandlers => null;

  void _add(String method, String path, List<RequestHandler> handlers, {Logger logger}) {
    final route = '$method$path';
    final sa = route.verifiedSegments;
    for(var handlerRoute in _handlers.keys) {
      if(sa.matches(handlerRoute.segments)) {
        throw Exception('duplicate route: $route');
      }
    }
    _handlers[route] = handlers;
    if(logger != null) _loggers[route] = logger;
    if(method == 'GET') options(path, [_corsHandler]);
  }

  RequestHandler get _corsHandler => (req, res) => res.send(data: 'sure', headers: {
    // TODO
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': '*',
    'Access-Control-Allow-Methods': 'POST,GET,DELETE,PUT,OPTIONS'
  });

  Future<void> _handle(HttpRequest httpRequest) async {
    final lookupMethod = (httpRequest.method == 'HEAD') ? 'GET' : httpRequest.method;
    final requestPath = '$lookupMethod${httpRequest.uri.path}';
    final routePath = _handlers.containsKey(requestPath) ? requestPath : requestPath.findRouterPath(_handlers.keys);
    final handlers = _handlers[routePath] ?? _notFoundHandlers ?? [];
    print(requestPath);
    if(handlers.isNotEmpty) {
      final logger = _loggers[routePath] ?? this.logger;
      final request = Request(this, httpRequest, requestPath.parseParams(routePath));
      final response = Response(request);
      try {
        await runZoned(() async {
          for(var handler in handlers) {
            await handler(request, response);
            if(response.isClosed) {
              return;
            }
          }},
          zoneSpecification: ZoneSpecification(
            print: (self, parent, zone, message) {
              final logMessage = logger.convertMessage(request, response, message);
              if(logMessage != null) {
                parent.print(self, logMessage);
              }
            }
          )
        );
      } catch(error, stackTrace) {
        print(logger.convertError(request, response, error, stackTrace));
      }
      if(response.isNotClosed) {
        await response.close();
      }
    } else {
      httpRequest.response.statusCode = 404;
      await httpRequest.response.close();
    }
    if(httpRequest.response.statusCode >= 400) {
      print('status ${httpRequest.response.statusCode}');
    }
  }
}

typedef ErrorConverter = String Function(Request req, Response res, Object error, StackTrace stackTrace);
typedef MessageConverter = String Function(Request req, Response res, String message);

class Logger {

  ErrorConverter errorConverter;
  MessageConverter messageConverter;

  String convertMessage(Request req, Response res, String message) {
    if(messageConverter != null) {
      return messageConverter(req, res, message);
    }
    return message;
  }

  String convertError(Request req, Response res, Object error, StackTrace stackTrace) {
    if(errorConverter != null) {
      return errorConverter(req, res, error, stackTrace);
    }
    return '$error\n$stackTrace';
  }
}

typedef RequestHandler = Future<void> Function(Request request, Response response);

class Request {
  final Server _server;
  final HttpRequest _httpRequest;
  final Map<String, String> _params;
  Request(this._server, this._httpRequest, this._params);
  Response _response;

  String create(String path) => path.replaceAllMapped(RegExp(r'<(\w+)>'), (m) => this[m[1]]);

  String operator [](String name) => _params[name] ?? query[name];
  operator []=(String name, String value) => _params[name] = value;

  HeaderValues get header => HeaderValues(headers);
  HttpHeaders get headers => _httpRequest.headers;
  Map<String, String> get params => _params;
  Map<String, String> get query => _httpRequest.uri.queryParameters;

  bool get isHead => method == 'HEAD';
  bool get isNotHead => !isHead;
  bool get isPartial => header[HttpHeaders.rangeHeader]?.startsWith('bytes=') == true;
  bool get isNotPartial => !isPartial;

  String get method => _httpRequest.method;
  List<List<int>> get ranges => header[HttpHeaders.rangeHeader].substring(6).split(',')
      .map((r) => r.trim().split('-').map((e) => int.tryParse(e.trim())).toList()).toList();

  Future<ServerWebSocket> upgrade() async {
    _response._closed = true; // don't _actually_ close this response, the websocket will handle it
    return await ServerWebSocket.upgrade(_httpRequest);
  }
}
class HeaderValues {
  final HttpHeaders _headers;
  HeaderValues(this._headers);
  String operator [](String name) => _headers.value(name);
}

class Response {

  final Request _request;
  final headers = <String, dynamic>{};
  Response(Request request) : _request = request {
    request?._response = this;
  }
  HttpRequest get _httpRequest => _request?._httpRequest;
  HttpResponse get _httpResponse => _httpRequest?.response;

  bool _closed = false;
  bool get isClosed => _closed;
  bool get isNotClosed => !isClosed;
  bool get isOpen => isNotClosed;
  bool get isNotOpen => !isOpen;

  void add(List<int> data) => _httpResponse.add(data);
  void write(data) => _httpResponse.write(data);

  int get status => _httpResponse.statusCode;
  set status(int value) => _httpResponse.statusCode = value;

  Future<void> render(Page page) => sendHtml(page.render());

  Future<void> send({int code, data, Map<String, dynamic> headers}) async {
    assert(isOpen, 'called send after response has already been closed');
    _closed = true;
    final statusCode = code ?? 200;
    final content = _getContent(statusCode, data);
    for(var header in (headers ?? this.headers).entries) {
      _httpResponse.headers.add(header.key, header.value);
    }
    _httpResponse.headers.add(HttpHeaders.serverHeader, 'oobium');
    _httpResponse.statusCode = statusCode;
    _httpResponse.contentLength = content.length;
    if(_httpRequest.method != 'HEAD') {
      await _httpResponse.addStream(content.stream);
    }
    await close();
  }

  Future<void> sendFile(File file) async {
    assert(isOpen, 'called sendFile after response has already been closed');
    if(await file.exists()) {
      final stat = await file.stat();
      final etag = 'todo'; // TODO
      if(_request.isPartial) {
        final ranges = _request.ranges;
        if(ranges.isEmpty) {
          return send(code: 416, data: 'Requested Range Not Satisfiable');
        }
        if(ranges.length > 1) {
          return send(code: 501, data: 'Multipart Ranges Not Supported');
        }
        final start = ranges[0][0];
        final end = min((ranges[0][1] ?? (stat.size - 1)), stat.size - 1);
        if(start > end) {
          return send(code: 416, data: 'Requested Range Not Satisfiable');
        }
        final condition = _request.header[HttpHeaders.ifRangeHeader];
        if(condition == null || condition == etag) {
          return send(code: 206, data: FileContent(file, stat.size, start, end), headers: {
            HttpHeaders.contentRangeHeader: 'bytes $start-$end/${stat.size}',
            HttpHeaders.contentTypeHeader: file.contentType.toString(),
          });
        }
      }
      return send(code: 200, data: FileContent(file, stat.size), headers: {
        HttpHeaders.acceptRangesHeader: 'bytes',
        HttpHeaders.contentTypeHeader: file.contentType.toString()
      });
    } else {
      return send(code: 404);
    }
  }

  Future<void> sendJson(FutureOr<dynamic> data) async => send(data: Json.encode(await data), headers: {
    HttpHeaders.contentTypeHeader: ContentType.json.toString(),
    // TODO
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': '*',
    'Access-Control-Allow-Methods': 'POST,GET,DELETE,PUT,OPTIONS'
  });

  Future<void> sendHtml(data) => send(data: data, headers: {
    HttpHeaders.contentTypeHeader: ContentType.html.toString()
  });

  Future<void> close() async {
    await _httpResponse.flush();
    await _httpResponse.close();
  }

  Content _getContent(int code, data) {
    if(data == null) {
      switch(code) {
        case HttpStatus.notFound: return StringContent('Not Found');
        case HttpStatus.forbidden: return StringContent('Forbidden');
        case HttpStatus.internalServerError: return StringContent('Internal Server Error');
      }
      return NullContent();
    }
    if(data is Content) {
      return data;
    }
    return StringContent(data.toString());
  }
}

abstract class Content {
  Stream<List<int>> get stream;
  int get length;
}
class FileContent implements Content {
  final File file;
  final int size, start, end;
  FileContent(this.file, this.size, [this.start, this.end]);
  @override int get length {
    if(start == null && end == null) return size;
    if(start == null) return end;
    if(end == null) return size - start;
    return end - start;
  }
  @override Stream<List<int>> get stream => file.openRead(start, end);
}
class NullContent implements Content {
  @override int get length => 0;
  @override Stream<List<int>> get stream => Stream.fromIterable([]);
}
class StringContent implements Content {
  final List<int> _data;
  StringContent(String data) : _data = utf8.encode(data);
  @override int get length => _data.length;
  @override Stream<List<int>> get stream => Stream.fromIterable([_data]);
}

class ServerWebSocket extends BaseWebSocket {
  ServerWebSocket(WebSocket ws) : super(ws);
  static Future<ServerWebSocket> upgrade(HttpRequest request) async => ServerWebSocket(await WebSocketTransformer.upgrade(request));
}

RequestHandler auth = (req, res) async {
  final authHeader = req.header[HttpHeaders.authorizationHeader];
  if(authHeader == 'Test 127.0.0.1' && req._server.settings.address == '127.0.0.1') {
    return;
  }
  final validator = Validator(req._server.settings.projectId);
  final validated = await validator.validate(authHeader);
  if(validated != true) {
    await res.send(code: HttpStatus.forbidden);
  }
};
