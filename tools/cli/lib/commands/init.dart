import 'dart:io';

import 'package:oobium_cli/commands/_base.dart';
import 'package:oobium_cli/models.dart';
import 'package:oobium_cli/prompt.dart';

class InitCommand extends ProjectCommand {
  @override final name = 'init';
  @override final description = 'initialize an oobium project';

  @override
  void runWithProject(Project project) {
    if(project.isOobium) {
      if(prompt('oobium configuration already exists. update it?')) {
        stdout.writeln('updating oobium configuration:');
      } else {
        return;
      }
    } else {
      stdout.writeln('creating oobium configuration:');
    }
    project.config.copyWith(
        address:    promptFor('address', initial: project.config.address),
        host:       promptFor('host', initial: project.config.host),
        subdomains: ['www', 'api'],
        email:      promptFor('email', initial: project.config.email)
    ).save();
  }
}
