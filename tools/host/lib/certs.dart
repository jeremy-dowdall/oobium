import 'package:tools_host/installer.dart';

/// https://certbot.eff.org/docs/using.html#webroot
Future<void> installCertBot() async {
  await run('snap', ['install', 'core']);
  await run('snap', ['refresh', 'core']);
  await run('snap', ['install', '--classic', 'certbot']);
  await run('ln', ['-s', '/snap/bin/certbot', '/usr/bin/certbot']);
  await run('certbot', ['certonly', '--webroot']);
  await run('certbot', ['renew', '--dry-run']);
}
