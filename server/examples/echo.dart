import 'package:oobium_server/src/server.dart';

void main() {
  final server = Server();

  server.get('/echo/<test>', [(req) => req['test']]);

  server.start();
}