import 'dart:async';
import 'dart:convert';
import 'dart:io' show File, Directory, ContentType, HttpRequest, HttpResponse, HttpServer, HttpStatus, HttpHeaders;
import 'dart:math';

import 'package:objectid/objectid.dart';
import 'package:oobium_server/src/config/server_config.dart';
import 'package:oobium_server/src/service.dart';
import 'package:oobium_websocket/oobium_websocket.dart';
import 'package:xstring/xstring.dart';

import 'watcher/watcher_.dart'
  if (dart.library.developer) 'watcher/watcher_io.dart' as watcher;

class Host {

  final String name;
  final Server _server;
  final _handlers = <String, List<RequestHandler>>{};
  final _loggers = <String, Logger>{};
  ServiceRegistry? _registry;
  Host._(this.name, this._server);

  ServerConfig get settings => _server.config;

  Logger? _logger;
  Logger get logger => _logger ?? _server.logger;
  set logger(Logger value) => _logger = value;

  RequestHandler? error404Handler;
  RequestHandler? error500Handler;

  void addService(Service service) {
    _registry ??= ServiceRegistry();
    _registry!.add(service);
    if(service.consumes == Host) {
      service.onAttach(this);
    }
  }
  void addServices(List<Service> services) {
    for(var service in services) {
      addService(service);
    }
  }
  T getService<T extends Service>() => _registry!.get<T>();
  
  void get(String path, List<RequestHandler> handlers, {Logger? logger}) => _add('GET', path, handlers, logger: logger);
  void head(String path, List<RequestHandler> handlers, {Logger? logger}) => _add('HEAD', path, handlers, logger: logger);
  void options(String path, List<RequestHandler> handlers, {Logger? logger}) => _add('OPTIONS', path, handlers, logger: logger);
  void patch(String path, List<RequestHandler> handlers, {Logger? logger}) => _add('PATCH', path, handlers, logger: logger);
  void post(String path, List<RequestHandler> handlers, {Logger? logger}) => _add('POST', path, handlers, logger: logger);
  void put(String path, List<RequestHandler> handlers, {Logger? logger}) => _add('PUT', path, handlers, logger: logger);
  void delete(String path, List<RequestHandler> handlers, {Logger? logger}) => _add('DELETE', path, handlers, logger: logger);

  /// directoryPath may be null to accommodate configurations being read in that may not include certain paths for certain environments
  void static(String? directoryPath, {String? at, String Function(String path)? pathBuilder, Logger? logger, bool live = false, bool optional = false}) {
    if(live) {
      final path = '/${at ?? directoryPath}/*'.replaceAll('//', '/');
      get(path, [(req) {
        if(req.uri.path.contains('..')) {
          return 400;
        }
        final filePath = '$directoryPath/${req.uri.path.substring(path.length-1)}';
        return File(filePath);
      }], logger: logger);
    } else {
      for(var file in _getFiles(directoryPath, optional: optional)) {
        final filePath = file.path;
        final basePath = filePath.substring(directoryPath!.length + 1);
        final builtPath = (pathBuilder != null) ? pathBuilder(basePath) : (at.isBlank ? '/$basePath' : '$at/$basePath');
        final routePath = builtPath.replaceAll(RegExp(r'/+|\\'), '/');
        get(routePath, [(req) => File(filePath)], logger: logger);
        if(routePath.endsWith('index.html')) {
          final impliedPath = routePath.substring(0, routePath.length - 10);
          get(impliedPath, [(req) => File(filePath)], logger: logger);
        }
      }
    }
  }

  void redirect(String from) => _server.hostRedirect(from: from, to: name);
  void subdomain(String name) => _server.hostSubdomain(host: this.name, sub: name);
  void subdomains(List<String> names) => _server.hostSubdomains(host: name, subs: names);

  Iterable<File> _getFiles(String? directoryPath, {optional = false}) {
    assert(directoryPath != null || optional, 'directoryPath cannot be null, unless optional is true');
    if(directoryPath == null) {
      print('directory not specified... skipping.');
    } else {
      final directory = Directory(directoryPath);
      final exists = directory.existsSync();
      assert(exists || optional, '${directory.absolute} not found. Directory must exist unless optional is true');
      if(exists) {
        return directory.listSync(recursive: true).whereType<File>();
      } else {
        print('${directory.absolute} not found... skipping.');
      }
    }
    return [];
  }

  List<RequestHandler>? get _notFoundHandlers => null;

  void _add(String method, String path, List<RequestHandler> handlers, {Logger? logger}) {
    final route = '$method$path';
    final sa = route.verifiedSegments;
    for(var handlerRoute in _handlers.keys) {
      if(sa.matches(handlerRoute.segments)) {
        throw 'duplicate route: $route';
      }
    }
    _handlers[route] = handlers;
    if(logger != null) _loggers[route] = logger;
    if(method == 'GET') options(path, [_handleCors]); // TODO cors handler
  }

  Future<void> _handle(HttpRequest httpRequest) async {
    final lookupMethod = (httpRequest.method == 'HEAD') ? 'GET' : httpRequest.method;
    final requestPath = '$lookupMethod${httpRequest.requestedUri.path}';
    final routePath = _handlers.containsKey(requestPath) ? requestPath : requestPath.findRouterPath(_handlers.keys);
    final request = Request(
      host: this,
      routePath: routePath ?? '',
      method: httpRequest.method,
      uri: httpRequest.requestedUri,
      headers: RequestHeaders(httpRequest),
      query: httpRequest.uri.queryParameters
    );
    var response;
    final sender = ResponseHandler(request, httpRequest);
    final handlers = _handlers[routePath] ?? _notFoundHandlers ?? [];
    print(requestPath);
    if(handlers.isNotEmpty) {
      final logger = _loggers[routePath] ?? this.logger;
      try {
        await runZoned(() async {
          for(final handler in handlers) {
            response = await handler(request);
            if(response != null) {
              return;
            }
          }},
            zoneSpecification: ZoneSpecification(
                print: (self, parent, zone, message) {
                  final logMessage = logger.convertMessage(request, message);
                  parent.print(self, logMessage);
                }
            )
        );
      } catch(error, stackTrace) {
        print(logger.convertError(request, error, stackTrace));
      }
    }
    response ??= await _handleError(request, 404);
    await sender.sendResponse(response);
    if(httpRequest.response.statusCode >= 400) {
      print('ERROR: ${httpRequest.requestedUri} -> ${httpRequest.response.statusCode}');
    }
  }

  FutureOr<dynamic> _handleCors(req) => Response(headers: {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': '*',
    'Access-Control-Allow-Methods': 'POST,GET,DELETE,PUT,OPTIONS',
  });

  FutureOr<dynamic> _handleError(Request req, int code) {
    if(code == 404 && error404Handler != null) {
      return error404Handler!(req);
    }
    if(code >= 500 && error500Handler != null) {
      return error500Handler!(req);
    }
    return Response(code: code);
  }

  final _sockets = <String, List<ServerWebSocket>>{};
  // List<ServerWebSocket> socket(String uid) => _sockets[uid];
  WsProxy socket(String uid) => WsProxy(uid, this);
}

class Server {

  final ServerConfig config;
  final _hosts = <String, Host>{};
  final _redirects = <String, Redirect>{};
  final _subdomains = <String, String>{};
  Server({
    String address='127.0.0.1',
    int port=8080,
  }) : config = ServerConfig(address: address, port: port);
  Server.config(this.config);
  static Future<Server> fromEnv() => ServerConfig.fromEnv()
      .then((config) => Server.config(config));

  Logger logger = Logger();

  var _started = false;
  HttpServer? http;
  HttpServer? https;
  StreamSubscription? httpSubscription;
  StreamSubscription? httpsSubscription;
  StreamSubscription? watcherSubscription;

  Host host([String name='']) {
    return _hosts.putIfAbsent(name, () => Host._(name, this));
  }

  void hostRedirect({required String from, required String to, bool temporary = false}) {
    _redirects[from] = Redirect(to, temporary);
  }
  
  void hostSubdomain({required String host, required String sub}) {
    _subdomains['$sub.$host'] = host;
  }

  void hostSubdomains({required String host, required List<String> subs}) {
    for(var sub in subs) {
      _subdomains['$sub.$host'] = host;
    }
  }

  void pause() {
    httpSubscription?.pause();
    httpsSubscription?.pause();
  }

  void resume() {
    httpSubscription?.resume();
    httpsSubscription?.resume();
  }

  Future<void> start() async {
    if(_started) {
      return;
    }
    _started = true;
    await _startServices();
    if(config.isSecure) {
      if(config.redirectHttp) {
        http = await HttpServer.bind(config.address, 80);
        httpSubscription = http!.listen((httpRequest) async => await _redirect(httpRequest, scheme: 'https'));
      }
      https = await HttpServer.bindSecure(config.address, config.port, config.securityContext);
      httpsSubscription = https!.listen((httpRequest) async => await _handle(httpRequest));
      print('Listening on https://${https!.address.host}:${https!.port}/ with redirect from http on port 80');
    } else {
      http = await HttpServer.bind(config.address, config.port);
      httpSubscription = http!.listen((httpRequest) async => await _handle(httpRequest));
      print('Listening on http://${http!.address.host}:${http!.port}/');
    }
    watcherSubscription = await watcher.start();
  }

  Future<void> stop() async {
    if(!_started) {
      return;
    }
    _started = false;
    await _stopServices();
    await httpSubscription?.cancel();
    await httpsSubscription?.cancel();
    await watcherSubscription?.cancel();
    httpSubscription = null;
    httpsSubscription = null;
    watcherSubscription = null;
  }

  Future<void> close({bool force = true}) async {
    await stop();
    await http?.close(force: force);
    await https?.close(force: force);
    http = null;
    https = null;
  }

  Future<void> _handle(HttpRequest request) async {
    final hostName = _hostName(request);
    if(hostName == null) {
      return _send(request, code: 400, data: 'Bad Request - Invalid Host Provided');
    }
    final redirect = _redirects[hostName];
    if(redirect != null) {
      return _redirect(request, host: redirect.host, temporary: redirect.temporary);
    }
    final host = _hosts[hostName] ?? _hosts[_subdomains[hostName]] ?? _hosts[''];
    if(host == null) {
      return _send(request, code: 400, data: 'Bad Request - Invalid Host');
    }
    return host._handle(request);
  }

  String? _hostName(HttpRequest request) {
    final headers = request.headers[HttpHeaders.hostHeader];
    if(headers != null && headers.length == 1 && headers[0].isNotEmpty == true) {
      return headers[0].split(':')[0];
    }
    return null;
  }

  Future<void> _redirect(HttpRequest request, {String? scheme, String? host, bool temporary = false}) async {
    return _send(request,
      code: temporary ? HttpStatus.movedTemporarily : HttpStatus.movedPermanently,
      data: 'Moved ${temporary ? 'Temporary' : 'Permanently'}',
      headers: {HttpHeaders.locationHeader: request.requestedUri.replace(scheme: scheme, host: host)}
    );
  }
  
  Future<void> _send(HttpRequest request, {required int code, Object? data, Map<String, Object>? headers}) async {
    request.response.statusCode = code;
    if(headers != null) {
      for(var header in headers.entries) {
        request.response.headers.add(header.key, header.value);
      }
    }
    request.response.headers.add(HttpHeaders.serverHeader, 'oobium');
    request.response.write(data);
    await request.response.flush();
    await request.response.close();
  }

  Future<void> _startServices() async {
    for(var host in _hosts.values) {
      await host._registry?.start();
    }
  }

  Future<void> _stopServices() async {
    for(var host in _hosts.values) {
      await host._registry?.stop();
    }
  }

  
  //--- Default HOST Convenience Methods ---//
  RequestHandler? get error404Handler => host().error404Handler;
  set error404Handler(RequestHandler? value) => host().error404Handler = value;

  RequestHandler? get error500Handler => host().error500Handler;
  set error500Handler(RequestHandler? value) => host().error500Handler = value;

  void addService(Service service) => host().addService(service);
  void addServices(List<Service> services) => host().addServices(services);
  T getService<T extends Service>() => host().getService<T>();
  void delete(String path, List<RequestHandler> handlers, {Logger? logger}) => host().delete(path, handlers, logger: logger);
  void get(String path, List<RequestHandler> handlers, {Logger? logger}) => host().get(path, handlers, logger: logger);
  void head(String path, List<RequestHandler> handlers, {Logger? logger}) => host().head(path, handlers, logger: logger);
  void options(String path, List<RequestHandler> handlers, {Logger? logger}) => host().options(path, handlers, logger: logger);
  void patch(String path, List<RequestHandler> handlers, {Logger? logger}) => host().patch(path, handlers, logger: logger);
  void post(String path, List<RequestHandler> handlers, {Logger? logger}) => host().post(path, handlers, logger: logger);
  void put(String path, List<RequestHandler> handlers, {Logger? logger}) => host().put(path, handlers, logger: logger);
  void static(String directoryPath, {String? at, String Function(String path)? pathBuilder, Logger? logger, optional = false}) => host().static(directoryPath, at: at, pathBuilder: pathBuilder, logger: logger, optional: optional);
}

class ServerWebSocket extends WebSocket {
  
  final String uid;
  final Host _host;
  ServerWebSocket._(String? id, this._host) : uid = id ?? ObjectId().hexString;
  
  WsProxy proxy(String uid) => WsProxy(uid, _host);
}

class WsProxy {

  final String _id;
  final Host _host;
  WsProxy(this._id, this._host);

  Future<Iterable<WsResult>> getAll(String path) {
    final sockets = _host._sockets[_id];
    if(sockets != null) {
      return Future.wait(sockets.map((s) => s.get(path)));
    } else {
      return Future.value([]);
    }
  }

  Future<WsResult> getAny(String path) async {
    final sockets = _host._sockets[_id];
    if(sockets != null) {
      for(var socket in sockets) {
        final result = await socket.get(path);
        if(result.isSuccess) {
          return result;
        }
      }
      return WsResult(406, 'No socket succeeded');
    } else {
      return WsResult(404, 'Socket not found');
    }
  }

  Future<Iterable<WsResult>> putAll(String path, data) {
    final sockets = _host._sockets[_id];
    if(sockets != null) {
      return Future.wait(sockets.map((s) => s.put(path, data)));
    } else {
      return Future.value([]);
    }
  }

  Future<WsResult> putAny(String path, data) async {
    final sockets = _host._sockets[_id];
    if(sockets != null) {
      for(var socket in sockets) {
        final result = await socket.put(path, data);
        if(result.isSuccess) {
          return result;
        }
      }
      return WsResult(406, 'No socket succeeded');
    } else {
      return WsResult(404, 'Socket not found');
    }
  }
}

class Redirect {
  final String host;
  final bool temporary;
  Redirect(this.host, this.temporary);
}

typedef ErrorConverter = String Function(Request req, Object error, StackTrace stackTrace);
typedef MessageConverter = String Function(Request req, String message);

class Logger {

  ErrorConverter? errorConverter;
  MessageConverter? messageConverter;

  String convertMessage(Request req, String message) {
    return messageConverter?.call(req, message) ?? message;
  }

  String convertError(Request req, Object error, StackTrace stackTrace) {
    return errorConverter?.call(req, error, stackTrace) ?? '$error\n$stackTrace';
  }
}

typedef RequestHandler = FutureOr<dynamic> Function(Request request);

class Request {
  final Host host;
  final String routePath;
  final String method;
  final Uri uri;
  final RequestHeaders headers;
  final query = <String, String>{};
  Request({
    required this.host,
    required this.routePath,
    required this.method,
    required this.uri,
    this.headers=const RequestHeaders.empty(),
    Map<String, String>? query
  }) {
    if(query != null) {
      this.query.addAll(query);
    }
  }

  String create(String path) => path.replaceAllMapped(RegExp(r'<(\w+)>'), (m) => this[m[1]!]);

  Map<String, String>? _params;
  String operator [](String name) => params[name] ?? query[name] ?? '';
  operator []=(String name, String value) => params[name] = value;

  Map<String, String> get params => _params ??= '$method${uri.path}'.parseParams(routePath);

  bool get isHead => method == 'HEAD';
  bool get isNotHead => !isHead;
  bool get isPartial => headers[HttpHeaders.rangeHeader]?.startsWith('bytes=') == true;
  bool get isNotPartial => !isPartial;

  List<List<int?>>? get ranges => headers[HttpHeaders.rangeHeader]?.substring(6).split(',')
      .map((r) => r.trim().split('-').map((e) => int.tryParse(e.trim())).toList()).toList();
}
class RequestHeaders {
  final Map<String, String> _headers;
  const RequestHeaders.empty() : _headers = const {};
  RequestHeaders.values(this._headers);
  RequestHeaders(HttpRequest request) : _headers = {} {
    request.headers.forEach((name, values) {
      _headers[name] = values.join(', ');
    });
  }
  String? operator [](String name) => _headers[name];
}

class Response {
  final int code;
  final Map<String, dynamic> headers;
  final dynamic data;
  Response({this.code=200, this.headers=const{}, this.data,});
  FutureOr<dynamic> resolve(Request request) => data;
}

class ResponseHandler {
  final Request request;
  final HttpRequest httpRequest;
  final HttpResponse httpResponse;
  ResponseHandler(this.request, this.httpRequest) : httpResponse = httpRequest.response;

  bool _closed = false;
  bool get isClosed => _closed;
  bool get isNotClosed => !isClosed;
  bool get isOpen => isNotClosed;
  bool get isNotOpen => !isOpen;

  Future<void> close() async {
    await httpResponse.flush();
    await httpResponse.close();
  }

  Future<void> send({int code=200, Map<String, dynamic> headers=const{}, data}) async {
    assert(isOpen, 'called send after response has already been closed');
    _closed = true;
    httpResponse.statusCode = code;
    final content = await _getContent(code, data);
    for(var header in headers.entries) {
      httpResponse.headers.add(header.key, header.value);
    }
    httpResponse.headers.add(HttpHeaders.serverHeader, 'oobium');
    httpResponse.contentLength = content.length;
    if(httpRequest.method != 'HEAD') {
      await httpResponse.addStream(content.stream);
    }
    await close();
  }

  Future<void> sendResponse(response) async {
    if(response is Future) {
      return sendResponse(await response);
    }
    if(response is Response) {
      return send(
        code: response.code,
        headers: response.headers,
        data: response.resolve(request)
      );
    }
    if(response is WebSocketResponse) {
      return response.handle(request, httpRequest);
    }
    if(response is int) {
      return send(code: response);
    }
    if(response is bool) {
      return response ? send() : close();
    }
    if(response is File) {
      return sendFile(response);
    }
    if(response is JsonResource) {
      return sendJson(response);
    }
    if(response is HtmlResource) {
      return sendHtml(response);
    }
    if(response is Resource) {
      return sendHtml(response);
    }
    if(response is String) {
      return sendHtml(response);
    }
    return sendJson(response);
  }

  Future<void> sendFile(File file) async {
    if(await file.exists()) {
      final stat = await file.stat();
      final etag = 'todo'; // TODO
      if(request.isPartial) {
        final ranges = request.ranges ?? [];
        if(ranges.isEmpty) {
          return send(code: 416, data: 'Requested Range Not Satisfiable');
        }
        if(ranges.length > 1) {
          return send(code: 501, data: 'Multipart Ranges Not Supported');
        }
        final start = ranges[0][0] ?? 0;
        final end = min((ranges[0][1] ?? (start + (5*1024*1024))), stat.size - 1);
        if(start > end) {
          return send(code: 416, data: 'Requested Range Not Satisfiable');
        }
        final condition = request.headers[HttpHeaders.ifRangeHeader];
        if(condition == null || condition == etag) {
          return send(code: 206, data: FileContent(file, stat.size, start, end + 1), headers: {
            HttpHeaders.contentRangeHeader:  'bytes $start-$end/${stat.size}',
            HttpHeaders.contentTypeHeader: file.contentType.toString(),
          });
        }
      }
      return send(code: 200, data: FileContent(file, stat.size), headers: {
        HttpHeaders.acceptRangesHeader: 'bytes',
        HttpHeaders.contentTypeHeader: file.contentType.toString(),
      });
    }
    return send(code: 404);
  }

  Future<void> sendHtml(html, {int code=200}) {
    return send(code: code, data: html, headers: {
      HttpHeaders.contentTypeHeader: ContentType.html.toString()
    });
  }

  Future<void> sendJson(data, {int code=200}) async {
    return send(code: code, data: data, headers: {
      HttpHeaders.contentTypeHeader: ContentType.json.toString(),
      // TODO
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Headers': '*',
      'Access-Control-Allow-Methods': 'POST,GET,DELETE,PUT,OPTIONS',
    });
  }

  Future<Content> _getContent(int code, data) async {
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
    if(data is Resource) {
      data = data.render();
    }
    if(data is Future) {
      return _getContent(code, await data);
    }
    return StringContent('$data');
  }
}

abstract class Resource {
  FutureOr<String> render();
}
abstract class HtmlResource extends Resource {}
abstract class JsonResource extends Resource {}

abstract class Content {
  Stream<List<int>> get stream;
  int get length;
}
class FileContent implements Content {
  final File file;
  final int size;
  final int? start, end;
  FileContent(this.file, this.size, [this.start, this.end]);
  @override int get length {
    if(start == null && end == null) return size;
    if(start == null) return end!;
    if(end == null) return size - start!;
    return end! - start!;
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

class WebSocketResponse {
  final FutureOr Function(ServerWebSocket socket) f;
  final String Function(List<String> protocols)? protocol;
  final bool autoStart;
  WebSocketResponse(this.f, this.protocol, this.autoStart);

  Future<void> handle(Request request, HttpRequest httpRequest) async {
    final host = request.host;
    final socket = ServerWebSocket._(request.params['uid'], host);
    print('add socket(${socket.uid})');
    host._sockets.putIfAbsent(socket.uid, () => <ServerWebSocket>[]).add(socket);
    socket.done.then((_) { // ignore: unawaited_futures
      print('remove socket(${socket.uid})');
      host._sockets.remove(socket.uid);
    });
    await f(socket);
    await socket.upgrade(httpRequest, protocol: protocol, autoStart: autoStart);
  }
}

RequestHandler websocket(FutureOr Function(ServerWebSocket socket) f, {String Function(List<String> protocols)? protocol, bool autoStart = true}) => (req) {
  return WebSocketResponse(f, protocol, autoStart);
};
