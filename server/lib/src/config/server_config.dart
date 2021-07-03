import 'dart:convert';
import 'dart:io';

class ServerConfig {

  final String address;
  final int port;
  final String certPath;
  final String keyPath;
  final bool redirectHttp;
  final bool _secure;
  bool get isSecure => _secure;
  bool get isNotSecure => !isSecure;
  late final securityContext = SecurityContext()..useCertificateChain(certPath)..usePrivateKey(keyPath);

  ServerConfig({
    required this.address,
    this.port=443,
    this.certPath='',
    this.keyPath='',
    this.redirectHttp=true,
  }) : _secure = certPath.isNotEmpty && keyPath.isNotEmpty;

  Map<String, dynamic> toJson() => {
    'address':  address,
    'port':     port,
    'certPath': certPath,
    'keyPath':  keyPath,
  };

  static Future<ServerConfig> fromEnv() async {
    final path = File(Platform.script.path).parent.path;
    final file = File('env/config.json').existsOrNull
        ?? File('$path/../env/config.json').existsOrNull
        ?? File('$path/env/config.json').existsOrNull;
    if(file == null) {
      throw 'cannot locate ServerConfig ($path)';
    }
    final json = jsonDecode(await file.readAsString());
    final config = ServerConfig(
      address:  json['address'] ?? '127.0.0.1',
      port:     json['port'] ?? 8080,
      certPath: json['certPath'] ?? '',
      keyPath:  json['keyPath'] ?? '',
    );
    if(config.isSecure) {
      if(!(await File(config.certPath).exists())) throw 'ServerConfig.certPath does not exist (${config.certPath})';
      if(!(await File(config.keyPath).exists())) throw 'ServerConfig.keyPath does not exist (${config.keyPath})';
    }
    return config;
  }
}

extension FileExistsX on File {
  File? get existsOrNull => existsSync() ? this : null;
}