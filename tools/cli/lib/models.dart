import 'dart:io';

import 'package:yaml/yaml.dart';

class Project {
  final Directory directory;
  final PubSpec pubSpec;
  final Settings config;
  Project({
    required this.directory,
    required this.pubSpec,
    required this.config
  });

  bool get isOobium => config.exists;

  @override
  toString() => 'Project(${pubSpec.name})';

  static Project load(Directory dir) {
    return Project(
      directory: dir,
      pubSpec: PubSpec.load(File('${dir.path}/pubspec.yaml')),
      config: Settings.load(File('${dir.path}/oobium.yaml')),
    );
  }
  static List<Project> find(Directory dir, {bool recursive=false}) {
    return dir.listSync(recursive: recursive)
        .whereType<File>()
        .where((f) => f.path.endsWith('${Platform.pathSeparator}pubspec.yaml'))
        .map((f) => Project.load(f.parent))
        .toList();
  }
}

class PubSpec {
  final File file;
  final String name;
  final String version;
  final String description;
  PubSpec({
    required this.file,
    required this.name,
    required this.version,
    required this.description
  });
  static PubSpec load(File file) {
    final yaml = loadYaml(file.readAsStringSync());
    return PubSpec(
        file: file,
        name: yaml['name'],
        version: yaml['version'],
        description: yaml['description'],
    );
  }
  static List<PubSpec> find(Directory dir, {bool recursive=false}) {
    return dir.listSync(recursive: recursive)
      .whereType<File>()
      .where((f) => f.path.endsWith('${Platform.pathSeparator}pubspec.yaml'))
      .map((f) => PubSpec.load(f))
      .toList();
  }
}

class Settings {
  final File file;
  final String address; // ip address
  final String host;
  final List<String> subdomains;
  final String email;  // contact
  Settings({
    required this.file,
    required this.address,
    required this.host,
    this.subdomains=const[],
    required this.email
  });

  Settings copyWith({
    File? file,
    String? address,
    String? host,
    List<String>? subdomains,
    String? email
  }) => Settings(
      file: file??this.file,
      address: address??this.address,
      host: host??this.host,
      subdomains: subdomains??this.subdomains,
      email: email??this.email
  );

  delete() {
    file.deleteSync();
    _exists = false;
  }
  save() {
    if(!exists) {
      file.createSync(recursive: true);
      _exists = true;
    }
    file.writeAsStringSync(
      'address: $address\n'
      'host: $host\n'
      'subdomains:\n  - ${subdomains.join('\n  - ')}\n'
      'email: $email\n'
    );
  }
  bool? _exists;
  bool get exists => _exists ??= file.existsSync();

  @override
  String toString() =>
    'OobiumConfig({\n'
    '  address:    $address\n'
    '  host:       $host\n'
    '  subdomains: $subdomains\n'
    '  email:      $email\n'
    '})'
  ;

  static Settings load(File file) {
    final yaml = file.existsSync() ? loadYaml(file.readAsStringSync()) : {};
    return Settings(
      file: file,
      address: yaml['address'] ?? '',
      host: yaml['host'] ?? '',
      subdomains: (yaml['subdomains'])?.toList().cast<String>() ?? [],
      email: yaml['email'] ?? '',
    );
  }
}

class MetaData {
  final File file;
  MetaData(this.file);
}

extension CliFileX on FileSystemEntity {
  bool get isMeta => (this is File) && path.endsWith('/.oobium.metadata');
  bool get isNotMeta => !isMeta;

  bool get isPubSpec => (this is File) && path.endsWith('/pubspec.yaml');
  bool get isNotPubSpec => !isPubSpec;

  bool get isSettings => (this is File) && path.endsWith('/oobium.yaml');
  bool get isNotSettings => !isSettings;

  bool get isProject {
    final fse = this;
    if(fse is Directory) {
      return fse.listSync().any((e) => e.isPubSpec);
    }
    return false;
  }
  bool get isNotProject => !isProject;

  bool get isOobium {
    final fse = this;
    if(fse is Directory) {
      return fse.listSync().any((e) => e.isSettings);
    }
    return false;
  }
  bool get isNotOobium => !isOobium;
}