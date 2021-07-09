import 'dart:async';
import 'dart:io';

import 'package:tools_common/models.dart';

import '../_base.dart';

class InitCommand extends OobiumCommand {

  @override final name = 'init';
  @override final description = 'initialize a new oobium host server';

  @override
  FutureOr<void> runWithOobiumProject(OobiumProject project) async {
    final address = project.config.address;
    final channel = '';
    final token = '';
    await ssh(address, [
      'wget https://oobium.download/oobium_boot-linux',
      'chmod +x oobium_boot-linux',
      './oobium_boot-linux a=$address c=$channel t=$token',
    ]);
  }
}

Future<void> ssh(String address, List<String> commands) async {
  final tmpDir = Directory('${Directory.systemTemp.path}/scripts');
  if(!tmpDir.existsSync()) {
    tmpDir.createSync(recursive: true);
  }
  final script = File('${tmpDir.path}/tmp-script.sh');
  script.writeAsStringSync(
    'ssh root@$address << EOF\n${commands.join('\n')}\nEOF\n'
  );
  final chmod = await Process.run('chmod', ['+x', script.path]);
  stdout.write(chmod.stdout);
  stderr.write(chmod.stderr);
  if(chmod.exitCode != 0) {
    return;
  }
  final process = await Process.start(script.path, []);
  stdout.addStream(process.stdout);
  stderr.addStream(process.stderr);
  if(process.exitCode != 0) {
    return;
  } else {
    script.deleteSync();
  }
}

String installDartScript() =>
r'''
sudo apt-get update

sudo apt-get install apt-transport-https
sudo sh -c 'wget -qO- https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add -'
sudo sh -c 'wget -qO- https://storage.googleapis.com/download.dartlang.org/linux/debian/dart_stable.list > /etc/apt/sources.list.d/dart_stable.list'

sudo apt-get update
sudo apt-get install dart

export PATH="$PATH:/usr/lib/dart/bin"
echo 'export PATH="$PATH:/usr/lib/dart/bin"' >> ~/.profile

dart --disable-analytics
dart --version
./main.exe
''';

String installHostScript({String branch='master',}) =>
'''
  mkdir /oobium
  mkdir /oobium/host
  mkdir /oobium/host/bin
  mkdir /oobium/host/env

  mkdir /oobium/host/build
  cd /oobium/host/build
  wget \'https://github.com/jeremy-dowdall/oobium/archive/$branch.tar.gz\'
  tar -xvzf $branch.tar.gz

  cd oobium-$branch/tools/host/
  dart pub get
  dart compile exe lib/main.dart -o /oobium/host/bin/oobium-host
  export PATH="\$PATH:/oobium/host/bin"
  echo \'export PATH="\$PATH:/oobium/host/bin"\' >> ~/.profile
  rm -rf /oobium/host/build
// ''';

String startHostScript() =>
'''
  pm2 restart oobium || pm2 start oobium-host --name oobium --cwd /oobium/host/env
''';

String startProjectScript(String project) =>
'''
  pm2 restart $project || pm2 start /oobium/host/$project/lib/server.exe --name $project --cwd /oobium/host/$project
''';


String installPm2Script() =>
'''
  echo install pm2
  wget -qO- https://getpm2.com/install.sh | bash
''';

String installCertbotScript() =>
'''
  echo install certbot
  snap install core; snap refresh core
  snap install --classic certbot
  ln -s /snap/bin/certbot /usr/bin/certbot
''';

String installCertificatesScript({
  required String email,
  required String host,
  List<String> subdomains=const[]
}) =>
'''
  echo install certificates / keys...
  certbot certonly -d $host -d www.$host --standalone -n --agree-tos --email $email
''';
