import 'package:tools_cli/commands/_base.dart';
import 'package:tools_common/models.dart';

class InfoCommand extends OobiumCommand {
  @override final name = 'info';
  @override final description = 'list information about an oobium project';

  @override
  void runWithOobiumProject(OobiumProject project) {
    print(
      'location: ${project.directory.absolute.uri}\n'
      'settings: {\n'
      '  address:    ${project.oobium.address}\n'
      '  host:       ${project.oobium.host}\n'
      '  subdomains: ${project.oobium.subdomains}\n'
      '  email:      ${project.oobium.email}\n'
      '}'
    );
  }
}
