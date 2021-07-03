import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:tar/tar.dart';

int? err;
String? cmd;

main([List<String> args=const[]]) async {
  final dartVersion = await getDartVersion();
  if(dartVersion != null) {
    print('dart version: $dartVersion');
  } else {
    await installDart();
  }

  final hostVersion = await getHostVersion();
  if(hostVersion != null) {
    print('host version: $hostVersion');
  } else {
    final exe = await installHost(parseBasePath(args));
    if(exe != null) {
      err ??= await runUntil(exe, [], (pout, perr) {
        final completer = Completer<int>();
        pout.listen((e) {
          stdout.write(e);
          if(utf8.decode(e).trim() == 'Oobium host started.') {
            completer.complete(0);
          }
        });
        stderr.addStream(perr);
        return completer.future;
      });
    }
  }

  if(err != null) {
    print('failed: $cmd');
  }
  exit(err ?? 0);
}

Future<String?> getDartVersion() async {
  try {
    final result = Process.runSync('dart', ['--version']);
    final str = StringBuffer();
    str.write(result.stdout);
    str.write(result.stderr);
    final s = str.toString();
    if(result.exitCode != 0) {
      stderr.writeln(s);
      stderr.writeln('exit(${result.exitCode})');
      return null;
    }
    final startStr = 'Dart SDK version: ';
    final end = s.indexOf(' (');
    if((s.startsWith(startStr) == false) || (end == -1)) {
      stderr.writeln('unrecognized output: $s');
      return null;
    }
    return s.substring(startStr.length, end);
  } on ProcessException {
    return null;
  }
}

Future<String?> getHostVersion() async {
  try {
    final result = Process.runSync('oobium-host', ['--version']);
    if(result.exitCode != 0) {
      stderr.writeln(result.stderr);
      return null;
    }
    final s = '${result.stdout}';
    final startStr = 'Oobium Host version: ';
    final end = s.indexOf(' (');
    if(s.startsWith(startStr) == false || (end == -1)) {
      stderr.writeln('unrecognized output: $s');
      return null;
    }
    return s.substring(startStr.length);
  } on ProcessException {
    return null;
  }
}

Future<void> installDart() async {
  if(Platform.isLinux) {
    err ??= await run('apt-get', ['update']);
    err ??= await run('apt-get', ['install', 'apt-transport-https']);
    err ??= await run('sh', ['-c', 'wget -qO- https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add -']);
    err ??= await run('sh', ['-c', 'wget -qO- https://storage.googleapis.com/download.dartlang.org/linux/debian/dart_stable.list > /etc/apt/sources.list.d/dart_stable.list']);
    err ??= await run('apt-get', ['update']);
    err ??= await run('apt-get', ['install', 'dart']);
    Directory('/usr/lib/dart/bin')..ensureExists()..addToPath();
  } else {
    cmd = 'install dart - platform not supported (${Platform.operatingSystem})';
    err = -1;
  }
}

Future<String?> installHost([String basePath='']) async {
  if(err != null) return null;

  final oobiumDir = Directory('${basePath}/oobium')..ensureExists();
  final hostDir = Directory('${oobiumDir.path}/host')..ensureExists();
  final binDir = Directory('${hostDir.path}/bin')..ensureExists();
  final envDir = Directory('${hostDir.path}/env')..ensureExists();
  final bldDir = Directory('${hostDir.path}/build')..ensureExists()..clean();
  final srcDir = Directory('${bldDir.path}/src')..ensureExists();
  File('${envDir.path}/config.json').writeAsStringSync('{}');

  final owner = 'jeremy-dowdall';
  final repo = 'oobium';
  final branch = 'server';
  final url = 'https://github.com/$owner/$repo/archive/$branch.tar.gz';

  cmd = 'download $repo@$branch from github';
  print('\n> $cmd\n');
  final client = HttpClient();
  final request = await client.getUrl(Uri.parse(url));
  final response = await request.close();
  if(response.statusCode != 200) {
    err = response.statusCode;
    return null;
  }

  stdout.write('receiving data .');
  final reader = TarReader(response.transform(gzip.decoder));
  while(await reader.moveNext()) {
    final entry = reader.current;
    if(entry.type == TypeFlag.reg) {
      final file = File('${srcDir.path}/${entry.header.name}')..createSync(recursive: true);
      stdout.write('.');
      await entry.contents.pipe(file.openWrite());
    }
  }
  await reader.cancel();
  client.close();
  stdout.writeln(' done.');

  final prjDir = Directory('${srcDir.path}/oobium-$branch/tools/host');
  final mainFile = File('${prjDir.path}/lib/main.dart');
  final exeFile = File('${binDir.path}/oobium-host');
  if(!mainFile.existsSync()) {
    cmd = 'mainFile does not exist (${mainFile.absolute.path})';
    err = -1;
  }

  err ??= await run('dart', ['pub', 'get'], wd: prjDir);
  err ??= await run('dart', ['compile', 'exe', mainFile.path, '-o', exeFile.path]);

  binDir.addToPath();

  if(err == null) {
    stdout.write('\nhost installed, removing build files...');
    bldDir.deleteSync(recursive: true);
    stdout.writeln(' done.');
    return exeFile.path;
  }
}

String parseBasePath(List<String> args) => args
    .firstWhere((s) => s.startsWith('base-path='),
    orElse: () => 'base-path=')
    .substring(10);

Future<int?> run(String executable, List<String> args, {Directory? wd}) async {
  cmd = '$executable ${args.join(' ')}${wd != null ? ' (in ${wd.absolute.path})' : ''}';
  print('\n> $cmd\n');
  try {
    final process = await Process.start(executable, args, workingDirectory: wd?.path);
    stdout.addStream(process.stdout);
    stderr.addStream(process.stderr);
    final code = await process.exitCode;
    return (code != 0) ? code : null;
  } catch(e) {
    cmd = '$cmd\n  $e';
    return -1;
  }
}

Future<int?> runUntil(
    String executable,
    List<String> args,
    Future<int?> Function(Stream<List<int>> stdout, Stream<List<int>> stdin) until, {
      Directory? wd,
    }) async {
  cmd = '$executable ${args.join(' ')}${wd != null ? ' (in ${wd.absolute.path})' : ''}';
  print('\n> $cmd\n');
  try {
    final process = await Process.start(executable, args, workingDirectory: wd?.path, mode: ProcessStartMode.detachedWithStdio);
    final code = await until(process.stdout, process.stderr);
    return (code != 0) ? code : null;
  } catch(e) {
    cmd = '$cmd\n  $e';
    return -1;
  }
}

extension DirectoryX on Directory {
  void addToPath() {
    if(Platform.isLinux) {
      final file = File('/root/.profile');
      final content = file.readAsStringSync();
      final pathEntry = absolute.path;
      if(content.contains(':$pathEntry')) {
        print('\nprofile already contains pathEntry, skipping');
      } else {
        print('\nwrite $pathEntry to .profile');
        file.writeAsStringSync(
          '${file.readAsStringSync()}\n'
          'export PATH="\$PATH:$pathEntry"\n'
        );
      }
    } else {
      print('\nskipping addToPath on non-Linux platform (${Platform.operatingSystem})');
    }
  }
  void clean() {
    if(existsSync()) {
      deleteSync(recursive: true);
      createSync(recursive: true);
    }
  }
  void ensureExists({bool recursive = true}) {
    if(!existsSync()) {
      createSync(recursive: recursive);
    }
  }
}
