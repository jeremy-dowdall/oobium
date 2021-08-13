import 'boot/boot.dart';

const version = const String.fromEnvironment('version');
const channel = const String.fromEnvironment('channel');

String get versionDisplayString =>
    '${const String.fromEnvironment('version', defaultValue: '-.-.-')}'
    ' (${const String.fromEnvironment('channel', defaultValue: 'debug')})';

Future<void> checkVersion() async {
  final env = Env.fromScript();
  if(env.isNotProd) {
    print('skipping version check in debug mode');
  } else {
    if(version.isEmpty) {
      throw 'version not set in prod (use --define=version=<version> during compilation)';
    }
    if(channel.isEmpty) {
      throw 'channel not set in prod (use --define=channel=<channel> during compilation)';
    }
  }
}

