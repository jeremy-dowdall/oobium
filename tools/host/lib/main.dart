import 'dart:io';

import 'server/server.dart' as server;
import 'version.dart';

main([List<String>? args]) async {
  await checkVersion();

  if(args?.contains('--version') == true) {
    stdout.writeln('Oobium Host version: $versionDisplayString');
    return;
  }

  stdout.writeln('Starting Oobium Host: $versionDisplayString');
  checkVersion();
  await server.start();
  stdout.writeln('Oobium Host started.');
}
