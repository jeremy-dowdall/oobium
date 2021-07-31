import 'dart:io';

Future<void> ssh(String address, List<String> commands) async {
  final tmpDir = Directory('${Directory.systemTemp.path}/scripts');
  if(!tmpDir.existsSync()) {
    tmpDir.createSync(recursive: true);
  }
  final script = File('${tmpDir.path}/tmp-script.sh');
  script.writeAsStringSync(
      'ssh root@$address << EOF\n${commands.join('\n')}\nEOF\n'
  );
  final chmod = await Process.run('chmod', ['+x', script.path]);
  stdout.write(chmod.stdout);
  stderr.write(chmod.stderr);
  if(chmod.exitCode != 0) {
    return;
  }
  final process = await Process.start(script.path, []);
  stdout.addStream(process.stdout);
  stderr.addStream(process.stderr);
  if(process.exitCode != 0) {
    return;
  } else {
    script.deleteSync();
  }
}
