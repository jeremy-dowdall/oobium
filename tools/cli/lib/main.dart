import 'package:args/command_runner.dart';
import 'package:tools_cli/commands/host.dart' show HostCommand;
import 'package:tools_cli/commands/info.dart';
import 'package:tools_cli/commands/init.dart';

///
/// - init new project
///   - create a remote.json file
/// - create a new build machine
/// - create a new host machine
/// - restart server
/// - update server
/// - dart builds (server)
/// - flutter builds (client/web)
///
void main(List<String> args) async {
  CommandRunner('oobium', 'a cli for oobium based applications')
    ..addCommand(InfoCommand())
    ..addCommand(InitCommand())
    ..addCommand(HostCommand())
    ..run(args);
}
