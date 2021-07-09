import 'dart:convert';
import 'dart:io';

Directory get envDir => Directory('${Directory('${Platform.script.path}').parent.parent.path}/env');
File get certFile => File('${envDir.path}/.cert');
File get configFile => File('${envDir.path}/config.json');
File get keyFile => File('${envDir.path}/.key');
File get tokenFile => File('${envDir.path}/.token');

late final _config = HostConfig.load();

String get address => _config.address;
String get channel => _config.channel;
int get port => 4430;
String get certificate => '${envDir.path}/.crt';
String get privateKey => '${envDir.path}/.key';
late final token = tokenFile.readAsStringSync();

class HostConfig {
  final String address;
  final String channel;
  const HostConfig({
    this.address='',
    this.channel=''
  });

  HostConfig copyWith({
    String? address,
    String? channel,
  }) => HostConfig(
    address: address ?? this.address,
    channel: channel ?? this.channel,
  );

  void save() {
    if(!configFile.existsSync()) {
      configFile.createSync(recursive: true);
    }
    configFile.writeAsStringSync(jsonEncode({
      'address': address,
      'channel': channel,
    }));
  }

  static HostConfig load() {
    if(configFile.existsSync()) {
      final data = jsonDecode(configFile.readAsStringSync());
      return HostConfig(
          address: data['address'],
          channel: data['channel']
      );
    } else {
      return const HostConfig();
    }
  }
}
