import 'package:args/command_runner.dart';

import 'host/deploy.dart';
import 'host/init.dart';
import 'host/status.dart';

class HostCommand extends Command {
  @override final name = 'host';
  @override final description = 'commands for managing projects on an oobium host';

  HostCommand() {
    addSubcommand(InitCommand());
    addSubcommand(StatusCommand());
    addSubcommand(DeployCommand());
  }
}
