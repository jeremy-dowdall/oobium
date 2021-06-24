import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:oobium_cli/models.dart';
import 'package:oobium_websocket/oobium_websocket.dart';

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

  FutureOr<void> runWithOobiumProject(Project project);

  @override
  void run() {
    final dir = Directory(argResults!['directory']);
    if(dir.isOobium) {
      runWithOobiumProject(Project.load(dir));
    } else {
      print('not an oobium project (${dir.uri})');
    }
  }
}

abstract class ConnectedCommand extends OobiumCommand {

  String get path => '/${parent?.name ?? name}';

  Future<void> runWithConnection(Project project, WebSocket ws);

  @override
  Future<void> runWithOobiumProject(Project project) async {
    final ws = await WebSocket().connect(path: path);
    try {
      await runWithConnection(project, ws);
    } finally {
      await ws.close();
    }
  }
}
