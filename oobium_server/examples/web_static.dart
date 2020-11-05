import 'package:oobium_server/src/server.dart';

void main() {
  final server = Server();

  server.static('examples/web');

  server.start();
}