import 'package:tools_host/commands/deploy.dart';
import 'package:tools_host/commands/status.dart';
import 'package:oobium_server/oobium_server.dart';

main() async {
  final server = Server();

  server.get('/host', [websocket((ws) { // TODO use an AuthSocket
    ws.on.getStream('/status', statusHandler);
    ws.on.getStream('/deploy', deployHandler);
  })]);

  await server.start();
}

