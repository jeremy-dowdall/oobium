import 'package:oobium_server/src/server.dart';

void main() async {
  final server = Server();

  server.get('/', [(req) => 'hello world!']);

  await server.start();
}