import 'package:oobium_server/oobium_server.dart';

import 'commands/certbot.dart';
import 'commands/deploy.dart';
import 'commands/status.dart';

import '../config.dart' as config;

Future<void> start() async {
  final server = await Server.secure(
    address: config.address,
    port: config.port,
    certificate: config.certificate,
    privateKey: config.privateKey,
    redirectInsecure: false,
  );

  server.get('/', [
    (req) {
      return (req.uri.host != '127.0.0.1') ? 403 : null;
    },
    websocket((ws) {
      ws.on.get('/acme-challenge/<file>', certbotHandler);
    }),
  ]);

  server.get('/host', [
    authorization(bearer: (token) {
      return (token != config.token) ? 401 : null;
    }),
    websocket((ws) {
      ws.on.getStream('/status', statusHandler);
      ws.on.put('/deploy', deployHandler);
    })
  ]);

  await server.start();
}
