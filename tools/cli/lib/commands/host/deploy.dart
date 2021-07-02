import 'dart:io';

import 'package:oobium_websocket/oobium_websocket.dart';
import 'package:tools_common/models.dart';
import 'package:tools_common/streams.dart';

import '../_base.dart';

class DeployCommand extends ConnectedCommand {
  @override final name = 'deploy';
  @override final description = 'deploy a project to an oobium host';

  @override
  Future<void> runWithConnection(Project project, WebSocket ws) async {
    final deployment = Deployment(
        name: project.pubspec.name,
        version: project.pubspec.version.toString()
    );

    final result = await ws.put('/deploy', deployment,
        onPut: {'/print': (req) => stdout.writeln(req.data)},
        onPutStream: {'stdout': (req) => req.stream.pipe(stdout)},
        onGetStream: {'/src': (req) => streamFiles(project.getSource())}
    );
    if(result.isNotSuccess) {
      print(result.data);
    }
  }
}
