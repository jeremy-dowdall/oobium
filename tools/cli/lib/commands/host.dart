import 'package:args/command_runner.dart';
import 'package:oobium_cli/commands/_base.dart';
import 'package:oobium_cli/models.dart';
import 'package:oobium_websocket/oobium_websocket.dart';

class HostCommand extends Command {
  @override final name = 'host';
  @override final description = 'commands for managing projects on an oobium host';

  HostCommand() {
    addSubcommand(StatusCommand());
  }
}

class StatusCommand extends ConnectedCommand {
  @override final name = 'status';
  @override final description = 'display the status for a project on an oobium host';

  @override
  Future<void> runWithConnection(Project project, WebSocket ws) async {
    final status = await ws.get('/status');
    if(status.isSuccess) {
      print('status: ${status.data}');
    }
  }
}

class DeployCommand extends ConnectedCommand {
  @override final name = 'deploy';
  @override final description = 'deploy a project to an oobium host';

  @override
  Future<void> runWithConnection(Project project, WebSocket ws) async {
    final status = await ws.put('/deploy', 'deployment descriptor type thing...');
    if(status.isSuccess) {
      print('status: ${status.data}');
    }
  }
}
