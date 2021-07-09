import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:oobium_websocket/oobium_websocket.dart';
import 'package:tools_cli/overrides.dart';
import 'package:tools_common/models.dart';

abstract class ProjectCommand extends Command {
  ProjectCommand() {
    argParser.addOption(
      'directory', abbr: 'd',
      help: 'project directory', defaultsTo: Directory.current.path
    );
  }

  FutureOr<void> runWithProject(Project project);

  @override
  void run() {
    final dir = Directory(argResults!['directory']);
    if(dir.isProject) {
      runWithProject(Project.load(dir));
    } else {
      print('not a valid project directory (${dir.uri})');
    }
  }
}

abstract class OobiumCommand extends Command {
  OobiumCommand() {
    argParser.addOption(
      'directory', abbr: 'd',
      help: 'project directory', defaultsTo: Directory.current.path
    );
  }

  FutureOr<void> runWithOobiumProject(OobiumProject project);

  @override
  void run() {
    final dir = Directory(argResults!['directory']);
    if(dir.isOobium) {
      runWithOobiumProject(OobiumProject.load(dir));
    } else {
      print('not an oobium project (${dir.uri})');
    }
  }
}

abstract class ConnectedCommand extends OobiumCommand {

  String get path => '/${parent?.name ?? name}';

  Future<void> runWithConnection(Project project, WebSocket ws);

  @override
  Future<void> runWithOobiumProject(OobiumProject project) async {
    OobiumHttpOverrides.set(project);
    try {
      final ws = await WebSocket().connect(
        secure: true,
        address: project.host.address,
        port: project.host.port,
        path: path,
        token: File('env/token').readAsStringSync()
      );
      try {
        await runWithConnection(project, ws);
      } finally {
        await ws.close();
      }
    } catch(e) {
      print('error: $e');
    }
  }
}
