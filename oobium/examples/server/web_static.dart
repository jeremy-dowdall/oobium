import 'package:oobium/src/server/server.dart';

void main() {
  final server = Server();

  server.static('examples/web');

  server.start();
}