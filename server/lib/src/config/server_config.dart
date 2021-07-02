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
    final file = File('env/server.json');
    if(!(await file.exists())) throw 'ServerConfig does not exist (${file.absolute.path})';
    final json = jsonDecode(await file.readAsString());
    final config = ServerConfig(
      address:  json['address'],
      port:     json['port'],
      certPath: json['certPath'],
      keyPath:  json['keyPath'],
    );
    if(config.isSecure) {
      if(!(await File(config.certPath).exists())) throw 'ServerConfig.certPath does not exist (${config.certPath})';
      if(!(await File(config.keyPath).exists())) throw 'ServerConfig.keyPath does not exist (${config.keyPath})';
    }
    return config;
  }
}
