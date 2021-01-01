import 'package:oobium/src/server/services/services.dart';

class HostService extends Service<Host> { }

class Host { }

class Server { }

class ServerWebSocket { }

typedef RequestHandler = Future<void> Function(Request request, Response response);

class Request { }

class Response { }