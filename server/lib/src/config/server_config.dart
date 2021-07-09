import 'dart:convert';
import 'dart:io';

class ServerConfig {

  final String address;
  final int port;
  final String certificate;
  final String privateKey;
  final String clientAuthorities;
  final bool redirect;
  final bool _secure;
  bool get isSecure => _secure;
  bool get isNotSecure => !isSecure;
  late final securityContext = () {
    final context = SecurityContext.defaultContext
      ..useCertificateChain(certificate)
      ..usePrivateKey(privateKey)
    ;
    if(clientAuthorities.isNotEmpty) {
      context.setClientAuthorities(clientAuthorities);
    }
    return context;
  }();

  ServerConfig({
    required this.address,
    this.port=443,
    this.certificate='',
    this.privateKey='',
    this.clientAuthorities='',
    this.redirect=true,
  }) : _secure = certificate.isNotEmpty && privateKey.isNotEmpty;

  Map<String, dynamic> toJson() => {
    'address': address,
    'port': port,
    'certificate': certificate,
    'privateKey': privateKey,
    'clientAuthorities': clientAuthorities,
    'redirect': redirect
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
      address: json['address'] ?? '127.0.0.1',
      port: json['port'] ?? 8080,
      certificate: json['certificate'] ?? '',
      privateKey: json['privateKey'] ?? '',
      clientAuthorities: json['clientAuthorities'] ?? '',
      redirect: json['redirect'] != false,
    );
    if(config.isSecure) {
      if(!(await File(config.certificate).exists())) throw 'ServerConfig.certificate does not exist (${config.certificate})';
      if(!(await File(config.privateKey).exists())) throw 'ServerConfig.privateKey does not exist (${config.privateKey})';
    }
    if(config.clientAuthorities.isNotEmpty) {
      if(!(await File(config.clientAuthorities).exists())) throw 'ServerConfig.clientAuthorities does not exist (${config.clientAuthorities})';
    }
    return config;
  }
}

extension FileExistsX on File {
  File? get existsOrNull => existsSync() ? this : null;
}