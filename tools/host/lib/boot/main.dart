import 'dart:io';

import 'boot.dart';

main([List<String> args=const[]]) async {
  try {
    final env = Env(args.dir, source: args.source);
    final dartVersion = await getDartVersion();
    if(dartVersion != null) {
      print('dart already installed: $dartVersion');
    } else {
      await installDart();
    }
    final hostVersion = env.isProd ? await getHostVersion(env) : null;
    if(hostVersion != null) {
      print('host already installed: $hostVersion');
    } else {
      await installHostSource(env, args.channel);
      await installHost(env, args.address, args.channel, args.token);
      await installCert(env, args.address);
      clean(env);
      await runUntil(env.exe.path, [], 'Oobium Host started.');
    }
  } catch(e) {
    print('build failed with $e');
    exitCode = (e is InstallException ? e.code : -1);
  }
}
