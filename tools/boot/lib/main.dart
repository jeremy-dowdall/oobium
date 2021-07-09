import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:pubspec_parse/pubspec_parse.dart';
import 'package:tar/tar.dart';


late final bool prod;
late final List<String> args;
int? err;
String? cmd;

main([List<String> a=const[]]) async {
  args = a;
  prod = const bool.fromEnvironment('dart.vm.product');
  print('prod: $prod');

  final dartVersion = await getDartVersion();
  if(dartVersion != null) {
    print('dart version: $dartVersion');
  } else {
    await installDart();
  }

  final hostVersion = prod ? await getHostVersion() : null;
  if(hostVersion != null) {
    print('host version: $hostVersion');
  } else {
    final exe = await installHost();
    if(exe != null) {
      err ??= await runUntil(exe, [], 'Oobium Host started.');
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

Future<void> installDart() async {
  if(Platform.isLinux) {
    err ??= await run('apt-get', ['update']);
    err ??= await run('apt-get', ['install', 'apt-transport-https']);
    err ??= await run('sh', ['-c', 'wget -qO- https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add -']);
    err ??= await run('sh', ['-c', 'wget -qO- https://storage.googleapis.com/download.dartlang.org/linux/debian/dart_stable.list > /etc/apt/sources.list.d/dart_stable.list']);
    err ??= await run('apt-get', ['update']);
    err ??= await run('apt-get', ['install', 'dart']);
    // Directory('/usr/lib/dart/bin')..ensureExists()..addToPath();
  } else {
    cmd = 'install dart - platform not supported (${Platform.operatingSystem})';
    err = -1;
  }
}

Future<String?> getHostVersion() async {
  try {
    final exe = '$dir/oobium/host/bin/oobium-host';
    final result = Process.runSync(exe, ['--version']);
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

Future<String?> installHost() async {
  if(err != null) return null;

  final oobiumDir = Directory('$dir/oobium')..ensureExists();
  final hostDir = Directory('${oobiumDir.path}/host')..ensureExists();
  final binDir = Directory('${hostDir.path}/bin')..ensureExists();
  final envDir = Directory('${hostDir.path}/env')..ensureExists();

  final Directory srcDir;
  final Directory prjDir;

  if(source.isEmpty) {
    srcDir = Directory('${hostDir.path}/source')..ensureExists();
    final result = await installSource(srcDir);
    if(result == null) {
      return null;
    } else {
      prjDir = result;
    }
  } else {
    if(prod) {
      cmd = 'source option is not valid on prod';
      err = -1;
      return null;
    }
    srcDir = Directory(source);
    prjDir = Directory('${srcDir.path}/tools/host');
  }

  final pubFile = File('${prjDir.path}/pubspec.yaml');
  if(!pubFile.existsSync()) {
    cmd = 'pubspec.yaml does not exist (${pubFile.absolute.path})';
    err = -1;
  }
  final version = Pubspec.parse(pubFile.readAsStringSync()).version;

  final mainFile = File('${prjDir.path}/lib/main.dart');
  final exeFile = File('${binDir.path}/oobium-host');
  if(!mainFile.existsSync()) {
    cmd = 'mainFile does not exist (${mainFile.absolute.path})';
    err = -1;
  }

  err ??= await run('dart', ['pub', 'get'], wd: prjDir);
  err ??= await run('dart', ['compile', 'exe', '--define=version=$version', '-o', exeFile.path, mainFile.path]);

  if(err == null) {
    File('${envDir.path}/config.json').writeAsStringSync(jsonEncode({
      "address": address,
      "channel": channel
    }));
    File('${envDir.path}/.token').writeAsStringSync(token);
    if(prod) {
      stdout.write('\nhost installed, removing build files...');
      srcDir.deleteSync(recursive: true);
      stdout.writeln(' done.');
    } else {
      stdout.writeln('\nhost installed.');
    }
    return exeFile.path;
  }
}

Future<Directory?> installSource(Directory srcDir) async {
  stdout.write('\ncleaning source dir (${srcDir.absolute.path})...');
  srcDir.clean();
  stdout.writeln(' done.');

  final owner = 'jeremy-dowdall';
  final repo = 'oobium';
  final branch = channel;
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

  return Directory('${srcDir.path}/oobium-$branch/tools/host');
}

late final address = args
    .firstWhere((s) => s.startsWith('a='),
    orElse: () => 'a=')
    .substring(2);

late final channel = args
    .firstWhere((s) => s.startsWith('c='),
    orElse: () => 'c=master')
    .substring(2);

late final dir = args
    .firstWhere((s) => s.startsWith('d='),
    orElse: () => 'd=')
    .substring(2);

late final source = args
    .firstWhere((s) => s.startsWith('s='),
    orElse: () => 's=')
    .substring(2);

late final token = args
    .firstWhere((s) => s.startsWith('t='),
    orElse: () => 't=')
    .substring(2);

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
    String pattern, {
      Directory? wd,
    }) async {
  cmd = '$executable ${args.join(' ')}${wd != null ? ' (in ${wd.absolute.path})' : ''}';
  print('\n> $cmd\n');
  try {
    final process = await Process.start(executable, args, workingDirectory: wd?.path, mode: ProcessStartMode.detachedWithStdio);
    stdout.writeln(' -- pid: ${process.pid} -- \n');
    final completer = Completer<int>();
    final buff = StringBuffer();
    process.stdout.listen((e) {
      stdout.add(e);
      buff.write(utf8.decode(e));
      if(buff.toString().contains(pattern)) {
        completer.complete(0);
      }
    });
    stderr.addStream(process.stderr);
    final code = await completer.future;
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
