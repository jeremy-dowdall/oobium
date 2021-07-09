import 'dart:io';

import 'package:tools_cli/commands/_base.dart';
import 'package:tools_cli/prompt.dart';
import 'package:tools_common/models.dart';

class InitCommand extends ProjectCommand {
  @override final name = 'init';
  @override final description = 'initialize an oobium project';

  @override
  void runWithProject(Project project) {
    final OobiumProject oobium;
    if(project is OobiumProject) {
      if(prompt('oobium configuration already exists. update it?')) {
        stdout.writeln('updating oobium configuration:');
        oobium = project;
      } else {
        return;
      }
    } else {
      stdout.writeln('creating oobium configuration:');
      oobium = project.toOobium();
    }
    final config = oobium.config.copyWith(
        address:    promptFor('address', initial: oobium.config.address),
        host:       promptFor('host', initial: oobium.config.host),
        subdomains: ['www', 'api'],
        email:      promptFor('email', initial: oobium.config.email)
    );
    if(!oobium.configFile.existsSync()) {
      oobium.configFile.createSync(recursive: true);
    }
    oobium.configFile.writeAsStringSync(config.toYaml());
  }
}
