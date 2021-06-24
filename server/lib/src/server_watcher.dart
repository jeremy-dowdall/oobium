import 'dart:async';
import 'dart:developer' as dev;
import 'dart:io';

import 'package:vm_service/utils.dart';
import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';
import 'package:watcher/watcher.dart';

Future<StreamSubscription?> start() async {
  final observatoryUri = (await dev.Service.getInfo()).serverUri;
  if (observatoryUri != null) {
    final wsUri = convertToWebSocketUrl(serviceProtocolUrl: observatoryUri);
    final serviceClient = await vmServiceConnectUri('$wsUri', log: StdoutLog());
    final vm = await serviceClient.getVM();
    final id = vm.isolates?.first.id;
    if (id != null) {
      final path = Directory('lib').absolute.path;
      print('observing source at $path');
      return Watcher(path).events.listen((_) async {
        await serviceClient.reloadSources(id);
        print('server reloaded');
      });
    }
  }
}

class StdoutLog extends Log {
  @override
  void warning(String message) => print(message);

  @override
  void severe(String message) => print(message);
}
