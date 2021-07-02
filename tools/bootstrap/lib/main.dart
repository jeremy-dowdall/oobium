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

  await installHost(parseBasePath(args));

  if(err != null) {
    print('failed executing: $cmd');
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
  err ??= await run('apt-get', ['update']);
  err ??= await run('apt-get', ['install', 'apt-transport-https']);
  err ??= await run('sh', ['-c', 'wget -qO- https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add -']);
  err ??= await run('sh', ['-c', 'wget -qO- https://storage.googleapis.com/download.dartlang.org/linux/debian/dart_stable.list > /etc/apt/sources.list.d/dart_stable.list']);
  err ??= await run('apt-get', ['update']);
  err ??= await run('apt-get', ['install', 'dart']);
  err ??= await run('export', [r'PATH="$PATH:/usr/lib/dart/bin"']);
  err ??= await run('echo', [r'export PATH="$PATH:/usr/lib/dart/bin"', '>>', '~/.profile']);
}

Future<void> installHost([String basePath='']) async {
  final oobiumDir = Directory('${basePath}/oobium')..ensureExists();
  final hostDir = Directory('${oobiumDir.path}/host')..ensureExists();
  final binDir = Directory('${hostDir.path}/bin')..ensureExists();
  final envDir = Directory('${hostDir.path}/env')..ensureExists();
  final bldDir = Directory('${hostDir.path}/build')..ensureExists();
  final srcDir = Directory('${bldDir.path}/src')..ensureExists();
  File('${envDir.path}/config.json').writeAsStringSync('{}');

  final repo = 'jeremy-dowdall/oobium';
  final branch = 'server';
  final github = 'https://github.com/$repo/archive/$branch.tar.gz';

  final client = HttpClient();
  final request = await client.getUrl(Uri.parse(github));
  final response = await request.close();
  final reader = TarReader(response.transform(gzip.decoder));
  while(await reader.moveNext()) {
    final entry = reader.current;
    if(entry.type == TypeFlag.reg) {
      final file = File('${srcDir.path}/${entry.header.name}')..createSync(recursive: true);
      await entry.contents.pipe(file.openWrite());
    }
  }
  await reader.cancel();
  client.close();

  // err ??= await run('wget', ['https://github.com/jeremy-dowdall/oobium/archive/$branch.tar.gz']);
  // err ??= await run('tar', ['-xvzf', tarPath, '-C', srcPath]);

  final prjDir = Directory('${srcDir.path}/oobium-$branch/tools/host');
  final mainFile = File('${prjDir.path}/lib/main.dart');
  if(!mainFile.existsSync()) {
    cmd = 'mainFile does not exist (${mainFile.absolute.path})';
    err = -1;
  }

  err ??= await run('dart', ['pub', 'get'], wd: prjDir);
  err ??= await run('dart', ['compile', 'exe', mainFile.path, '-o', '${binDir.path}/oobium-host']);

  err ??= await run('export', ['PATH="\$PATH:${binDir.path}"']);
  err ??= await run('echo', ['export PATH="\$PATH:${binDir.path}"', '>>', '~/.profile']);
}

String parseBasePath(List<String> args) => args
    .firstWhere((s) => s.startsWith('base-path='),
    orElse: () => 'base-path=')
    .substring(10);

Future<int?> run(String executable, List<String> args, {Directory? wd}) async {
  cmd = '$executable ${args.join(' ')}${wd != null ? ' (in ${wd.absolute.path})' : ''}';
  print('\n> $cmd\n');
  final process = await Process.start(executable, args);
  stdout.addStream(process.stdout);
  stderr.addStream(process.stderr);
  final code = await process.exitCode;
  return (code != 0) ? code : null;
}

extension DirectoryX on Directory {
  void ensureExists({bool recursive = true}) {
    if(!existsSync()) {
      createSync(recursive: recursive);
    }
  }
}
