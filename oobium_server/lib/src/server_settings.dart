import 'dart:convert';
import 'dart:io';

class ServerSettings {

  static Future<ServerSettings> load([String path = 'env/server.json']) async {
    return ServerSettings._(jsonDecode(await File(path).readAsString()));
  }

  final _settings = <String, dynamic>{};
  ServerSettings._(Map<String, dynamic> settings) {
    _settings.addAll(settings);
  }
  ServerSettings({
    String? address,
    int? port,
    String? certPath,
    String? keyPath,
    String? cachePath,
    String? webroot,
    Map<String, dynamic>? custom
  }) {
    _settings['server'] ??= {};
    if(address != null) _settings['server']['address'] = address;
    if(port != null) _settings['server']['port'] = port;
    if(certPath != null) _settings['server']['certPath'] = certPath;
    if(keyPath != null) _settings['server']['keyPath'] = keyPath;
    if(cachePath != null) _settings['server']['cachePath'] = cachePath;
    if(webroot != null) _settings['server']['webroot'] = webroot;
    if(custom != null) {
      _settings.addAll(custom);
    }
  }

  dynamic operator [](String key) => _settings[key];
  operator []=(String key, dynamic value) => _settings[key] = value;

  bool get isDebug => isNotProduction;
  bool get isNotDebug => !isDebug;
  bool get isProduction => _settings['mode'] == 'production';
  bool get isNotProduction => !isProduction;

  bool get isSecure => (certPath != null) && (keyPath != null) && File(certPath!).existsSync() && File(keyPath!).existsSync();
  bool get isNotSecure => !isSecure;
  String? get certPath => _settings['server']['certPath'];
  String? get keyPath => _settings['server']['keyPath'];

  String get protocol => isSecure ? 'https' : 'http';
  String get address => _settings['server']['address'] ?? '127.0.0.1';
  String get host => _settings['server']['host'];
  int get port => _settings['server']['port'] ?? (isSecure ? 443 : 8080);
  SecurityContext? get securityContext => isSecure ? (SecurityContext()..useCertificateChain(certPath!)..usePrivateKey(keyPath!)) : null;
  String get cachePath => _settings['server']['cachePath'] ?? 'cache';
  String get webroot => _settings['web']['path'] ?? 'www';
}

class HostSettings {

}

class FirebaseConfig {
  final String apiKey;
  final String authDomain;
  final String databaseURL;
  final String projectId;
  final String storageBucket;
  final String messagingSenderId;
  FirebaseConfig({
    required this.apiKey,
    required this.authDomain,
    required this.databaseURL,
    required this.projectId,
    required this.storageBucket,
    required this.messagingSenderId
  });
}

