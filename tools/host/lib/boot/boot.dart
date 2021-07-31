import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:pubspec_parse/pubspec_parse.dart';
import 'package:tar/tar.dart';

class Env {
  final _prod = const bool.fromEnvironment('dart.vm.product');
  final Directory oobium;
  final Directory certbot;
  final Directory host;
  final Directory bin;
  final Directory env;
  final Directory src;
  final Directory prj;
  final bool _source;
  Env(String root, {String source=''}) :
    oobium = Directory('$root/oobium'),
    certbot = Directory('$root/certbot'), // TODO ???
    host = Directory('$root/oobium/host'),
    bin = Directory('$root/oobium/host/bin'),
    env = Directory('$root/oobium/host/env'),
    src = source.isEmpty
        ? Directory('$root/oobium/host/source')
        : Directory(source),
    prj = source.isEmpty
        ? Directory('$root/oobium/host/source/tools/host')
        : Directory('$source/tools/host'),
    _source = source.isEmpty
  ;
  factory Env.fromScript() {
    final root = File(Platform.script.path).parent.parent.path;
    return Env(root);
  }
  void createAll() {
    oobium.ensureExists();
    host.ensureExists();
    bin.ensureExists();
    env.ensureExists();
    src.ensureExists();
    prj.ensureExists();
  }
  bool get isProd => _prod;
  bool get isNotProd => !isProd;
  bool get isLocalSource => _source;
  bool get isNotLocalSource => !isLocalSource;
  File get pubspec => File('${prj.path}/pubspec.yaml');
  File get main => File('${prj.path}/lib/main.dart');
  File get exe => File('${bin.path}/oobium-host');
  File get config => File('${env.path}/config.json');
  File get crt => File('${env.path}/.crt');
  File get key => File('${env.path}/.key');
  File get token => File('${env.path}/.token');
}

class InstallException implements Exception {
  final String message;
  final int code;
  InstallException(this.message, [int? code]) : code = code ?? -1;
  @override
  String toString() => 'exit($code): $message';
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

Future<String> testInstall() {
  return Future.delayed(Duration(seconds: 2)).then((value) => 'done');
}

Future<void> installDart() async {
  if(Platform.isLinux) {
    await run('apt-get', ['update']);
    await run('apt-get', ['install', 'apt-transport-https']);
    await run('sh', ['-c', 'wget -qO- https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add -']);
    await run('sh', ['-c', 'wget -qO- https://storage.googleapis.com/download.dartlang.org/linux/debian/dart_stable.list > /etc/apt/sources.list.d/dart_stable.list']);
    await run('apt-get', ['update']);
    await run('apt-get', ['install', 'dart']);
    // Directory('/usr/lib/dart/bin')..ensureExists()..addToPath();
  } else {
    throw InstallException('install dart - platform not supported (${Platform.operatingSystem})');
  }
}

Future<String?> getHostVersion(Env env) async {
  try {
    final result = Process.runSync(env.exe.path, ['--version']);
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
  } catch(e) {
    throw InstallException('$e');
  }
}

Future<void> installHost(Env env, String address, String channel, String token) async {
  final version = Pubspec.parse(env.pubspec.readAsStringSync()).version;

  await run('dart', ['pub', 'get'], wd: env.prj);
  await run('dart', ['compile', 'exe',
    '--define=version=$version,channel=$channel',
    '-o', env.exe.path,
    env.main.path
  ]);

  env.config.writeAsStringSync(jsonEncode({
    "address": address,
    "channel": channel
  }));
  env.token.writeAsStringSync(token);
}

Future<void> installHostSource(Env env, String channel) async {
  if(env.isLocalSource) {
    if(env.isProd) {
      throw InstallException('local source is not allowed in prod mode');
    } else {
      return;
    }
  }

  stdout.write('\ncleaning source dir (${env.src.absolute.path})...');
  env.src.clean();
  stdout.writeln(' done.');

  final owner = 'jeremy-dowdall';
  final repo = 'oobium';
  final branch = channel;
  final root = '$repo-$branch';
  final url = 'https://github.com/$owner/$repo/archive/$branch.tar.gz';

  final cmd = 'download $root from github';
  print('\n> $cmd\n');
  final client = HttpClient();
  final request = await client.getUrl(Uri.parse(url));
  final response = await request.close();
  if(response.statusCode != 200) {
    throw InstallException(cmd, response.statusCode);
  }

  stdout.write('receiving data .');
  final reader = TarReader(response.transform(gzip.decoder));
  while(await reader.moveNext()) {
    final entry = reader.current;
    if(entry.type == TypeFlag.reg) {
      final path = entry.header.name.substring(root.length);
      final file = File('${env.src.path}/$path')..createSync(recursive: true);
      stdout.write('.');
      await entry.contents.pipe(file.openWrite());
    }
  }
  await reader.cancel();
  client.close();
  stdout.writeln(' done.');
}

Future<void> installCert(Env env, String address) {
  return run('openssl', [
    'req', '-x509',
    '-newkey', 'rsa:4096',
    '-sha256',
    '-days', '3650',
    '-nodes',
    '-keyout', env.key.path,
    '-out', env.crt.path,
    '-subj', '"/CN=oobium.com"',
    '-addext', '"subjectAltName=IP:$address"'
  ]);
}

int? clean(Env env) {
  if(env.isProd) {
    if(env.isNotLocalSource) {
      stdout.write('\nremoving build files...');
      env.src.deleteSync(recursive: true);
      stdout.writeln(' done.');
    }
  } else {
    stdout.writeln('\nskipping clean in debug mode.');
  }
}

Future<void> run(String executable, List<String> args, {Directory? wd}) async {
  final cmd = '$executable ${args.join(' ')}${wd != null ? ' (in ${wd.absolute.path})' : ''}';
  print('\n> $cmd\n');
  try {
    final process = await Process.start(executable, args, workingDirectory: wd?.path);
    stdout.addStream(process.stdout);
    stderr.addStream(process.stderr);
    final code = await process.exitCode;
    if(code != 0) {
      throw InstallException(cmd, code);
    }
  } catch(e) {
    throw InstallException('$cmd\n  $e');
  }
}

Future<void> runUntil(
    String executable,
    List<String> args,
    String pattern, {
      Directory? wd,
    }) async {
  final cmd = '$executable ${args.join(' ')}${wd != null ? ' (in ${wd.absolute.path})' : ''}';
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
    if(code != 0) {
      throw InstallException(cmd, code);
    }
  } catch(e) {
    throw InstallException('$cmd\n  $e');
  }
}

extension DirectoryX on Directory {
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

extension ArgListX on List<String> {
  String get address => valueOf('a');
  String get channel => valueOf('c');
  String get dir => valueOf('d');
  String get source => valueOf('s');
  String get token => valueOf('t');
  String valueOf(String key) => firstWhere(
      (s) => s.startsWith('$key='),
      orElse: () => '$key='
  ).substring('$key='.length);
}
