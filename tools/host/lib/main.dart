import 'package:oobium_host/commands/build.dart';
import 'package:oobium_host/commands/status.dart';
import 'package:oobium_server/oobium_server.dart';

main() async {
  final server = Server();

  server.get('/host', [websocket((ws) { // TODO use an AuthSocket
    ws.on.get('/status', statusHandler);
    ws.on.get('/build', buildHandler);
  })]);

  await server.start();
}

