import 'dart:convert';

import 'package:build/build.dart';
import 'package:dart_style/dart_style.dart';
import 'package:oobium_routing_gen/src/routes_generator.dart';

class RoutesBuilder implements Builder {
  @override
  Future build(BuildStep buildStep) async {
    final inputId = buildStep.inputId;
    final contents = await buildStep.readAsString(inputId);
    final lines = LineSplitter.split(contents);
    final primary = RoutesParser(lines).parse();
    if(primary != null) {
      final formatter = DartFormatter();
      final gen = RoutesGenerator.generate(inputId.pathSegments.last, primary);
      await buildStep.writeAsString(
        inputId.replace('routes.dart', 'routes.g.dart'),
        formatter.format(gen.routesLibrary)
      );
      if(lines.contains('const genProvider = true;')) {
        await buildStep.writeAsString(
          inputId.replace('routes.dart', 'routes.g.provider.dart'),
          formatter.format(gen.providerLibrary)
        );
      }
    }
  }

  @override
  final buildExtensions = const {
    'routes.dart': ['routes.g.dart', 'routes.g.provider.dart']
  };
}
extension AssetIdX on AssetId {
  AssetId replace(String from, String to) {
    return AssetId(package, path.replaceFirst(from, to));
  }
}