import 'dart:io';

import 'package:pubspec_parse/pubspec_parse.dart';
import 'package:yaml/yaml.dart';

class Project {
  final Directory directory;
  final Pubspec pubspec;
  final File pubspecFile;

  Project({
    required this.directory,
    required this.pubspec,
    required this.pubspecFile,
  });

  bool get isOobium => false;

  late final buildDir = Directory('${directory.path}/build/host');

  OobiumProject toOobium() => OobiumProject(
      directory: directory,
      pubspec: pubspec,
      pubspecFile: pubspecFile,
      config: Settings(),
      configFile: File('${directory.path}/oobium.yaml')
  );

  @override
  toString() => 'Project(${pubspec.name})';

  static Project load(Directory dir) {
    final pubspecFile = File('${dir.path}/pubspec.yaml');
    final oobiumFile = File('${dir.path}/oobium.yaml');
    if(oobiumFile.existsSync()) {
      return OobiumProject(
        directory: dir,
        pubspec: Pubspec.parse(pubspecFile.readAsStringSync()),
        pubspecFile: pubspecFile,
        config: Settings.parse(oobiumFile.readAsStringSync()),
        configFile: oobiumFile,
      );
    }
    return Project(
      directory: dir,
      pubspec: Pubspec.parse(pubspecFile.readAsStringSync()),
      pubspecFile: pubspecFile,
    );
  }
  static List<Project> find(Directory dir, {bool recursive=false}) {
    return dir.listSync(recursive: recursive)
        .whereType<Directory>()
        .where((d) => d.isProject)
        .map((d) => Project.load(d))
        .toList();
  }
}

class OobiumProject extends Project {
  final Settings config;
  final File configFile;
  OobiumProject({
    required Directory directory,
    required Pubspec pubspec,
    required File pubspecFile,
    required this.config,
    required this.configFile,
  }) : super(
    directory: directory,
    pubspec: pubspec,
    pubspecFile: pubspecFile,
  );

  bool get isOobium => true;

  @override
  toString() => 'Project(${pubspec.name})';

  static OobiumProject load(Directory dir) {
    final pubspecFile = File('${dir.path}/pubspec.yaml');
    final oobiumFile = File('${dir.path}/oobium.yaml');
    return OobiumProject(
      directory: dir,
      pubspec: Pubspec.parse(pubspecFile.readAsStringSync()),
      pubspecFile: pubspecFile,
      config: Settings.parse(oobiumFile.readAsStringSync()),
      configFile: oobiumFile,
    );
  }
  static List<OobiumProject> find(Directory dir, {bool recursive=false}) {
    return dir.listSync(recursive: recursive)
        .whereType<Directory>()
        .where((d) => d.isOobium)
        .map((d) => OobiumProject.load(d))
        .toList();
  }
}

class Settings {
  final String address; // ip address
  final String host;
  final List<String> subdomains;
  final String email;  // contact
  Settings({
    this.address='',
    this.host='',
    this.subdomains=const[],
    this.email=''
  });

  Settings copyWith({
    String? address,
    String? host,
    List<String>? subdomains,
    String? email
  }) => Settings(
      address: address??this.address,
      host: host??this.host,
      subdomains: subdomains??this.subdomains,
      email: email??this.email
  );

  @override
  String toString() =>
      'OobiumConfig({\n'
      '  address:    $address\n'
      '  host:       $host\n'
      '  subdomains: $subdomains\n'
      '  email:      $email\n'
      '})'
  ;

  String toYaml() =>
    'address: $address\n'
    'host: $host\n'
    'subdomains:\n  - ${subdomains.join('\n  - ')}\n'
    'email: $email\n'
  ;

  static Settings parse(String yaml) {
    final data = loadYaml(yaml);
    return Settings(
      address: data['address'] ?? '',
      host: data['host'] ?? '',
      subdomains: (data['subdomains'])?.toList().cast<String>() ?? [],
      email: data['email'] ?? '',
    );
  }
}

class MetaData {
  final File file;
  MetaData(this.file);
}

class Deployment {
  final String name;
  final String version;
  Deployment({
    required this.name,
    required this.version
  });
  Deployment.fromJson(data) :
      name = data['name'],
      version = data['version'];
  Map<String, dynamic> toJson() => {
    'name': name,
    'version': version
  };
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
      return File('${fse.path}/pubspec.yaml').existsSync();
    }
    return false;
  }
  bool get isNotProject => !isProject;

  bool get isOobium {
    final fse = this;
    if(fse is Directory) {
      return File('${fse.path}/oobium.yaml').existsSync();
    }
    return false;
  }
  bool get isNotOobium => !isOobium;
}

extension ProjectFilesX on Project {

  Map<String, File> getSource() {
    final start = directory.absolute.path.length;
    final files = {
      for(final f in source)
        'project${f.absolute.path.substring(start)}': f
    };
    for(final e in pathDependencies.entries) {
      files.addAll(getDependentSource(e.key, e.value));
    }
    // for(final e in files.entries) {
    //   print('${e.key} -> ${e.value.path}');
    // }
    // return {};
    return files;
  }

  Map<String, File> getDependentSource(String name, String path) {
    final start = directory.absolute.path.length;
    final newPath = 'dependencies/$name';
    final project = Project.load(dir(path));
    final files = {
      for(final f in project.source)
        f.path.substring(start).replaceFirst(path, newPath): f
    };
    for(final e in project.pathDependencies.entries) {
      files.addAll(project.getDependentSource(e.key, e.value));
    }
    return files;
  }

  void copy(String path, Directory to) {
    File('${directory.path}$path').copySync('${to.path}/pubspec.yaml');
  }

  Directory dir(String path) => Directory('${directory.path}/$path');

  bool exists(String path) => type(path) != FileSystemEntityType.notFound;
  FileSystemEntityType type(String path) => FileSystemEntity.typeSync('${directory.path}/$path');

  File file(String path) => File('${directory.path}/$path');

  List<File> files(String path, {bool recursive=true}) =>
      Directory('${directory.path}/$path')
          .listSync(recursive: recursive)
          .whereType<File>()
          .toList();

  String? read(String path) => exists(path) ? file(path).readAsStringSync() : null;

  void write(String path, String? data) {
    final file = this.file(path);
    if(data == null) {
      if(file.existsSync()) {
        file.deleteSync(recursive: true);
      }
    } else {
      if(!file.existsSync()) {
        file.createSync(recursive: true);
      }
      file.writeAsStringSync(data);
    }
  }

  List<File> get source => [
    file('pubspec.yaml'),
    if(exists('pubspec.lock')) file('pubspec.lock'),
    ...files('lib')
  ];

  List<Project> get dependencies => pubspec.dependencies.values
      .whereType<PathDependency>()
      .map((d) => Directory(d.path))
      .where((d) => d.isProject)
      .map((d) => Project.load(d))
      .toList();

  Map<String, String> get pathDependencies => {
    for(final e in pubspec.dependencies.entries)
      if(e.value is PathDependency) e.key: (e.value as PathDependency).path
  };
}
