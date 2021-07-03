import 'dart:io';

import 'package:tools_host/commands/deploy.dart';
import 'package:tools_host/commands/status.dart';
import 'package:oobium_server/oobium_server.dart';

import 'commands/certbot.dart';

main([List<String>? args]) async {
  if(args?.contains('--version') == true) {
    stdout.writeln(
        'Oobium Host version:'
        ' ${const String.fromEnvironment('version', defaultValue: '')}'
        ' (${const String.fromEnvironment('channel', defaultValue: 'debug')})'
    );
    return;
  }

  final server = await Server.fromEnv();

  server.get('/', [
    (req) {
      return (req.uri.host != '127.0.0.1') ? 403 : null;
    },
    websocket((ws) {
      ws.on.get('/acme-challenge/<file>', certbotHandler);
    }),
  ]);

  server.get('/host', [websocket((ws) { // TODO use an AuthSocket?
    ws.on.getStream('/status', statusHandler);
    ws.on.put('/deploy', deployHandler);
  })]);

  await server.start();

  stdout.writeln('Oobium host started.');
}

