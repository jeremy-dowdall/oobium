import 'dart:io';

import 'package:oobium_websocket/oobium_websocket.dart';
import 'package:tools_common/models.dart';
import 'package:tools_common/processes.dart';
import 'package:tools_common/streams.dart';

// Stream<List<int>> deployHandler(WsRequest req) async* {
  // final result = await req.socket.put('/exec', 'please enter a command');
  // if(result.isSuccess) {
  //   final cmd = '${result.data}'.split(' ');
  //   yield* run(cmd[0], cmd.skip(1).toList());
  // }
// }

deployHandler(WsRequest req) async {
  final deployment = Deployment.fromJson(req.data);
  final bldDir = Directory('./build/host/${deployment.name}/${deployment.version}');
  if(bldDir.existsSync()) {
    // throw 'version already exists';
    bldDir.deleteSync(recursive: true);
  }
  bldDir.createSync(recursive: true);

  await req.socket.getStream('/src').pipe(
      FileStreamConsumer(bldDir, (msg) => req.socket.put('/print', msg))
  );
  await req.socket.flush();

  await req.socket.put('/print', 'updating pubspec files');
  updatePubspec(Directory('${bldDir.path}/project'), isProject: true);
  final dependencies = Directory('${bldDir.path}/dependencies');
  if(dependencies.existsSync()) {
    for(final dir in dependencies.listSync().whereType<Directory>()) {
      updatePubspec(dir);
    }
  }

  final wd = '${bldDir.path}/project';
  Directory('${bldDir.path}/outputs')..createSync();

  await req.socket.put('/print', 'resolving dependencies');
  await stdout.addStream(run('dart', ['pub', 'get'], workingDirectory: wd));
  await req.socket.put('/print', 'compiling standalone executable');
  await stdout.addStream(run('dart', ['compile', 'exe', '-o', '../outputs/main.exe', 'lib/main.dart'], workingDirectory: wd));
  await req.socket.put('/print', 'done.');
}

void updatePubspec(Directory dir, {bool isProject=false}) {
  final project = Project.load(dir);
  if(project.pathDependencies.isNotEmpty) {
    var pub = project.read('pubspec.yaml');
    var lock = project.read('pubspec.lock');
    for(final e in project.pathDependencies.entries) {
      final from = e.value;
      final to = isProject ? '../dependencies/${e.key}' : '../${e.key}';
      pub = pub?.replaceFirst(from, to);
      lock = lock?.replaceFirst(from, to);
    }
    project.write('pubspec.yaml', pub);
    project.write('pubspec.lock', lock);
  }
}