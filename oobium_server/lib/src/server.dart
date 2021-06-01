import 'dart:async';
import 'dart:convert';
import 'dart:io' show File, Directory, ContentType, HttpRequest, HttpResponse, HttpServer, HttpStatus, HttpHeaders;
import 'dart:isolate';
import 'dart:math';

import 'package:objectid/objectid.dart';
import 'package:oobium/oobium.dart';
import 'package:oobium_server/src/html/html.dart';
import 'package:oobium_server/src/server_settings.dart';
import 'package:oobium_server/src/service.dart';

class Host {

  final String name;
  final Server _server;
  final _handlers = <String, List<RequestHandler>>{};
  final _loggers = <String, Logger>{};
  ServiceRegistry? _registry;
  Host._(this.name, this._server);

  ServerSettings get settings => _server.settings;

  Logger? _logger;
  Logger get logger => _logger ?? _server.logger;
  set logger(Logger value) => _logger = value;

  RequestHandler? error404Handler;
  RequestHandler? error500Handler;

  bool livePages = false;

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

  void static(String directoryPath, {String? at, String Function(String path)? pathBuilder, Logger? logger, optional = false}) {
    if(livePages) {
      final path = '/${at ?? directoryPath}/*'.replaceAll('//', '/');
      get(path, [(req, res) {
        if(req.path.contains('..')) {
          return res.send(code: 400);
        }
        final filePath = '$directoryPath/${req.path.substring(path.length-1)}';
        return res.sendFile(File(filePath));
      }], logger: logger);
    } else {
      for(var file in _getFiles(directoryPath, optional: optional)) {
        final filePath = file.path;
        final basePath = filePath.substring(directoryPath.length + 1);
        final builtPath = (pathBuilder != null) ? pathBuilder(basePath) : (at.isBlank ? '/$basePath' : '$at/$basePath');
        final routePath = builtPath.replaceAll(RegExp(r'/+|\\'), '/');
        get(routePath, [(req, res) => res.sendFile(File(filePath))], logger: logger);
        if(routePath.endsWith('index.html')) {
          final impliedPath = routePath.substring(0, routePath.length - 10);
          get(impliedPath, [(req, res) => res.sendFile(File(filePath))], logger: logger);
        }
      }
    }
  }

  void redirect(String from) => _server.hostRedirect(from: from, to: name);
  void subdomain(String name) => _server.hostSubdomain(host: this.name, sub: name);
  void subdomains(List<String> names) => _server.hostSubdomains(host: name, subs: names);

  Iterable<File> _getFiles(String directoryPath, {optional = false}) {
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
    final request = Request(this, routePath ?? '', httpRequest);
    final response = Response(request);
    final handlers = _handlers[routePath] ?? _notFoundHandlers ?? [];
    print(requestPath);
    if(handlers.isNotEmpty) {
      final logger = _loggers[routePath] ?? this.logger;
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
        await _handleError(request, response, 404);
      }
    } else {
      await _handleError(request, response, 404);
    }
    if(httpRequest.response.statusCode >= 400) {
      print('ERROR: ${httpRequest.requestedUri} -> ${httpRequest.response.statusCode}');
    }
  }

  Future<void> _handleCors(req, res) {
    // TODO
    res.headers['Access-Control-Allow-Origin'] = '*';
    res.headers['Access-Control-Allow-Headers'] = '*';
    res.headers['Access-Control-Allow-Methods'] = 'POST,GET,DELETE,PUT,OPTIONS';
    return res.send(data: 'sure');
  }

  Future<void> _handleError(Request req, Response res, int code) {
    if(code == 404 && error404Handler != null) {
      return error404Handler!(req, res);
    }
    if(code >= 500 && error500Handler != null) {
      return error500Handler!(req, res);
    }
    return res.send(code: code);
  }

  final _sockets = <String, List<ServerWebSocket>>{};
  // List<ServerWebSocket> socket(String uid) => _sockets[uid];
  WsProxy socket(String uid) => WsProxy(uid, this);
}

class Server {

  final ServerSettings settings;
  final _hosts = <String, Host>{};
  final _redirects = <String, Redirect>{};
  final _subdomains = <String, String>{};
  Server({
    String address='127.0.0.1',
    int port=8080,
    String? certPath,
    String? keyPath,
    ServerSettings? settings
  }) : settings = settings ?? ServerSettings() {
    this.settings['server']['address'] ??= address;
    this.settings['server']['port'] ??= port;
    this.settings['server']['certPath'] ??= certPath;
    this.settings['server']['keyPath'] ??= keyPath;
  }

  Logger logger = Logger();

  HttpServer? http;
  HttpServer? https;
  StreamSubscription? httpSubscription;
  StreamSubscription? httpsSubscription;

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
    await _startServices();
    if(http == null) {
      await _createServers();
    }
    await httpSubscription?.cancel();
    await httpsSubscription?.cancel();
    if(https == null) {
      httpSubscription = http!.listen((httpRequest) async => await _handle(httpRequest));
      print('Listening on http://${http!.address.host}:${http!.port}/');
    } else {
      httpSubscription = http!.listen((httpRequest) async => await _redirect(httpRequest, scheme: 'https'));
      httpsSubscription = https!.listen((httpRequest) async => await _handle(httpRequest));
      print('Listening on https://${https!.address.host}:${https!.port}/ with redirect from http on port 80');
    }
  }

  Future<void> stop() async {
    await _stopServices();
    await httpSubscription?.cancel();
    await httpsSubscription?.cancel();
    httpSubscription = null;
    httpsSubscription = null;
  }

  Future<void> close({bool force = true}) async {
    await stop();
    await http?.close(force: force);
    await https?.close(force: force);
    http = null;
    https = null;
  }

  Future<void> _createServers() async {
    final securityContext = settings.securityContext;
    if(securityContext != null) {
      http = await HttpServer.bind(settings.address, 80);
      https = await HttpServer.bindSecure(settings.address, settings.port, securityContext);
    } else {
      http = await HttpServer.bind(settings.address, settings.port);
    }
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

  bool get livePages => host().livePages;
  set livePages(bool value) => host().livePages = value;

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

typedef ErrorConverter = String Function(Request req, Response res, Object error, StackTrace stackTrace);
typedef MessageConverter = String Function(Request req, Response res, String message);

class Logger {

  ErrorConverter? errorConverter;
  MessageConverter? messageConverter;

  String convertMessage(Request req, Response res, String message) {
    return messageConverter?.call(req, res, message) ?? message;
  }

  String convertError(Request req, Response res, Object error, StackTrace stackTrace) {
    return errorConverter?.call(req, res, error, stackTrace) ?? '$error\n$stackTrace';
  }
}

typedef RequestHandler = Future<void> Function(Request request, Response response);

class Request {
  final Host host;
  final String routePath;
  final String method;
  final String path;
  final RequestHeaders headers;
  final query = <String, String>{};
  final HttpRequest? _httpRequest;
  Request(this.host, this.routePath, HttpRequest httpRequest) :
    method = httpRequest.method,
    path = httpRequest.requestedUri.path,
    headers = RequestHeaders(httpRequest),
    _httpRequest = httpRequest
  {
    query.addAll(httpRequest.uri.queryParameters);
  }
  Request.values({
    required this.host,
    this.routePath='/',
    this.method='GET',
    this.path='/',
    this.headers=const RequestHeaders.empty(),
    Map<String, String>? query
  }) :
    _httpRequest = null
  {
    if(query != null) {
      this.query.addAll(query);
    }
  }

  late Response _response;

  String create(String path) => path.replaceAllMapped(RegExp(r'<(\w+)>'), (m) => this[m[1]!]);

  Map<String, String>? _params;
  String operator [](String name) => params[name] ?? query[name] ?? '';
  operator []=(String name, String value) => params[name] = value;

  Map<String, String> get params => _params ??= '$method$path'.parseParams(routePath);

  bool get isHead => method == 'HEAD';
  bool get isNotHead => !isHead;
  bool get isPartial => headers[HttpHeaders.rangeHeader]?.startsWith('bytes=') == true;
  bool get isNotPartial => !isPartial;

  List<List<int?>>? get ranges => headers[HttpHeaders.rangeHeader]?.substring(6).split(',')
      .map((r) => r.trim().split('-').map((e) => int.tryParse(e.trim())).toList()).toList();

  ServerWebSocket _websocket() {
    final socket = ServerWebSocket._(params['uid']!, host);
    host._sockets.putIfAbsent(socket.uid, () => <ServerWebSocket>[]).add(socket);
    socket.done.then((_) {
      host._sockets.remove(socket.uid);
    });
    _response._closed = true; // don't _actually_ close this response, the websocket will handle it
    return socket;
  }
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

  final Request? _request;
  final headers = <String, dynamic>{};
  Response(Request? request) : _request = request {
    request?._response = this;
  }
  HttpRequest? get _httpRequest => _request?._httpRequest;
  HttpResponse? get _httpResponse => _httpRequest?.response;

  bool _closed = false;
  bool get isClosed => _closed;
  bool get isNotClosed => !isClosed;
  bool get isOpen => isNotClosed;
  bool get isNotOpen => !isOpen;

  void add(List<int> data) => _httpResponse!.add(data);
  void write(data) => _httpResponse!.write(data);

  int get statusCode => _httpResponse!.statusCode;
  set statusCode(int value) => _httpResponse!.statusCode = value;

  bool get _livePages => _request!.host.livePages && _request!.host.settings.isDebug;

  Future<void> render<T extends Json>(PageBuilder<T> builder, T data) async {
    if(_livePages) {
      final source = await _findSource(builder.runtimeType.toString(), T.toString());
      if(source != null) {
        return _renderSource(source, data);
      }
    }
    return sendPage(builder.build(data));
  }

  Future<void> send({int code=200, data}) async {
    assert(isOpen, 'called send after response has already been closed');
    _closed = true;
    statusCode = code;
    final content = _getContent(data);
    for(var header in (headers).entries) {
      _httpResponse!.headers.add(header.key, header.value);
    }
    _httpResponse!.headers.add(HttpHeaders.serverHeader, 'oobium');
    _httpResponse!.contentLength = content.length;
    if(_httpRequest!.method != 'HEAD') {
      await _httpResponse!.addStream(content.stream);
    }
    await close();
  }

  Future<void> sendFile(File file) async {
    if(await file.exists()) {
      final stat = await file.stat();
      final etag = 'todo'; // TODO
      if(_request!.isPartial) {
        final ranges = _request!.ranges ?? [];
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
        final condition = _request!.headers[HttpHeaders.ifRangeHeader];
        if(condition == null || condition == etag) {
          headers[HttpHeaders.contentRangeHeader] =  'bytes $start-$end/${stat.size}';
          headers[HttpHeaders.contentTypeHeader] ??= file.contentType.toString();
          return send(code: 206, data: FileContent(file, stat.size, start, end + 1));
        }
      }
      headers[HttpHeaders.acceptRangesHeader] = 'bytes';
      headers[HttpHeaders.contentTypeHeader] ??= file.contentType.toString();
      return send(code: 200, data: FileContent(file, stat.size));
    }
    return send(code: 404);
  }

  Future<void> sendHtml(html, {int code=200}) {
    headers[HttpHeaders.contentTypeHeader] = ContentType.html.toString();
    return send(code: code, data: html);
  }

  Future<void> sendJson(FutureOr<dynamic> data, {int code=200}) async {
    headers[HttpHeaders.contentTypeHeader] = ContentType.json.toString();
    // TODO
    headers['Access-Control-Allow-Origin'] = '*';
    headers['Access-Control-Allow-Headers'] = '*';
    headers['Access-Control-Allow-Methods'] = 'POST,GET,DELETE,PUT,OPTIONS';
    return send(code: code, data: Json.encode(await data));
  }

  Future<void> sendPage(Page page, {int code=200}) => sendHtml(page.render(), code: code);

  Future<void> close() async {
    await _httpResponse?.flush();
    await _httpResponse?.close();
  }

  Future<String?> _findSource(String builderType, String dataType) async {
    final classDeclaration = 'class $builderType extends PageBuilder<$dataType>';
    final views = Directory('lib/www/views');
    for(var file in (await views.list(recursive: true).toList())) {
      final source = await File(file.path).readAsString();
      if(source.contains(classDeclaration)) {
        return source;
      }
    }
    return null;
  }

  Content _getContent(data) {
    if(data == null) {
      switch(statusCode) {
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

  Future<void> _renderSource(String source, Json data) async {

    // TODO really just need the imports... it re-compiles / builds everything

    final matches = RegExp(r'class (\w+) extends PageBuilder<(\w+)>').firstMatch(source);
    final builder = matches!.group(1);
    final dataType = matches.group(2);

    final content = '''
      import 'dart:convert';
      import 'dart:isolate';
  
      $source
  
      void main(args, SendPort port) {
        final data = $dataType.fromJson(jsonDecode(args[0]));
        final page = $builder().build(data);
        final html = page.render();
        port.send(html);
      }
    ''';
    print(content);

    final uri = Uri.dataFromString(content, mimeType: 'application/dart');
    final port = ReceivePort();
    final isolate = await Isolate.spawnUri(uri, [data.toJsonString()], port.sendPort);
    final String html = await port.first;

    port.close();
    isolate.kill();

    return sendHtml(html);
  }
}

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

RequestHandler websocket(FutureOr Function(ServerWebSocket socket) f, {String Function(List<String> protocols)? protocol, bool autoStart = true}) => (req, res) async {
  final socket = req._websocket();
  await f(socket);
  await socket.upgrade(req._httpRequest, protocol: protocol, autoStart: autoStart);
};
