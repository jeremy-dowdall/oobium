import 'dart:io';

import 'package:pubspec_parse/pubspec_parse.dart';
import 'package:yaml/yaml.dart';

class Project {
  final Directory directory;
  final Pubspec pubspec;

  Project({
    required this.directory,
    required this.pubspec,
  });

  bool get isOobium => false;

  late final pubspecFile = File('${directory.path}/pubspec.yaml');
  late final buildDir = Directory('${directory.path}/build/host');

  OobiumProject toOobium() => OobiumProject.load(directory);

  @override
  toString() => 'Project(${pubspec.name})';

  static Project load(Directory dir) {
    final pubspecFile = File('${dir.path}/pubspec.yaml');
    final oobiumFile = File('${dir.path}/oobium.yaml');
    if(oobiumFile.existsSync()) {
      return OobiumProject(
        directory: dir,
        pubspec: Pubspec.parse(pubspecFile.readAsStringSync()),
        config: OobiumConfig.parse(oobiumFile.readAsStringSync()),
      );
    }
    return Project(
      directory: dir,
      pubspec: Pubspec.parse(pubspecFile.readAsStringSync()),
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
  final OobiumConfig config;
  final OobiumHost host;
  final OobiumSite site;
  OobiumProject({
    required Directory directory,
    required Pubspec pubspec,
    this.config=const OobiumConfig(),
    this.host=const OobiumHost(),
    this.site=const OobiumSite()
  }) : super(
    directory: directory,
    pubspec: pubspec
  );

  bool get isOobium => true;

  late final configFile = File('${directory.path}/oobium.yaml');
  late final envDir = File('${directory.path}/env');
  late final hostFile = File('${envDir.path}/host.json');
  late final siteFile = File('${envDir.path}/site.json');

  @override
  toString() => 'Project(${pubspec.name})';

  static OobiumProject load(Directory dir) {
    final pubspecFile = File('${dir.path}/pubspec.yaml');
    return OobiumProject(
      directory: dir,
      pubspec: Pubspec.parse(pubspecFile.readAsStringSync()),
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

class OobiumConfig {
  final String email;  // contact
  final String address;
  final String host;
  final List<String> subdomains;
  const OobiumConfig({
    this.email='',
    this.address='',
    this.host='',
    this.subdomains=const[],
  });

  OobiumConfig copyWith({
    String? email,
    String? address,
    String? host,
    List<String>? subdomains,
  }) => OobiumConfig(
    email: email??this.email,
    address: address??this.address,
    host: host??this.host,
    subdomains: subdomains??this.subdomains,
  );

  Map<String, dynamic> toJson() => {
    'email': email,
    'address': address,
    'host': host,
    'subdomains': subdomains
  };

  @override
  String toString() =>
    'OobiumConfig({\n'
    '  email:      $email\n'
    '  address:    $address\n'
    '  host:       $host\n'
    '  subdomains: $subdomains\n'
    '})'
  ;

  String toYaml() =>
    'email: $email\n'
    'host: $host\n'
    'address: $address\n'
    'subdomains:\n  - ${subdomains.join('\n  - ')}\n'
  ;

  static OobiumConfig parse(String yaml) {
    final data = loadYaml(yaml);
    return OobiumConfig(
      email: data['email'] ?? '',
      host: data['host'] ?? '',
      address: data['address'] ?? '',
      subdomains: (data['subdomains'])?.toList().cast<String>() ?? [],
    );
  }
}

class OobiumHost {
  final String address;
  final int port;
  final String cert; // path to file
  final String token;
  const OobiumHost({
    this.address='10.0.0.95', //'',
    this.port=4430, //-1,
    this.cert='env/oobium_host.cert',
    this.token=''
  });

  OobiumHost copyWith({
    String? address,
    int? port,
    String? cert,
    String? token
  }) => OobiumHost(
    address: address??this.address,
    port: port??this.port,
    cert: cert??this.cert,
    token: token??this.token
  );
}

class OobiumSite {
  final String host;    // public domain name
  final List<String> subdomains;
  const OobiumSite({
    this.host='',
    this.subdomains=const[],
  });

  OobiumSite copyWith({
    String? host,
    List<String>? subdomains,
  }) => OobiumSite(
    host: host??this.host,
    subdomains: subdomains??this.subdomains,
  );
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
