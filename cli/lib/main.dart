import 'dart:io';

void main() {
  final current = Directory.current;
  print('cwd: $current');

  final projects = current.listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('${Platform.pathSeparator}pubspec.yaml'));
  print('projects: $projects');


}
