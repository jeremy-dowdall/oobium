import 'package:oobium_gen/src/model_builder.dart';
import 'package:oobium_gen/src/schema.dart';
import 'package:oobium/src/string.extensions.dart';

// String generateInitializersLibrary(Schema schema, String modelsImport) {
//   final imports = <String>[
//     modelsImport,
//     "import 'package:oobium/oobium.dart';",
//   ].toSet().toList()..sort();
//
//   final initializers = InitializersBuilder(imports: imports, models: schema.models);
//
//   return initializers.build();
// }

String generateModelsLibrary(Schema schema) {
  final imports = <String>[
    ...schema.imports,
    "import 'package:oobium/oobium.dart';",
  ].toSet().toList()..sort();

  final dbname = '${schema.name.camelCase}Data';
  final models = schema.models.map((model) => ModelBuilder(model));

  return '''
      ${imports.join('\n')}
      
      class $dbname extends Database {
        $dbname(String path) : super('\$path/${schema.name.underscored}', [
          ${models.map((m) => '(data) => ${m.ctor}.fromJson(data)').join(',\n')}
        ]);
      }
      
      ${models.map((model) => model.build()).join('\n')}
    ''';
}

// String generateScaffoldingLibrary(Schema schema, String modelsImport) {
//   final imports = <String>[
//     modelsImport,
//     ...schema.imports,
//     "import 'dart:async';",
//     "import 'package:flutter/material.dart';",
//     "import 'package:oobium_flutter/oobium_flutter.dart';",
//     "import 'package:oobium/oobium.dart';",
//     "import 'package:provider/provider.dart';",
//   ].toSet().toList()..sort();
//
//   final models = schema.models.where((model) => model.scaffold).expand((m) => m.expanded).map((model) => ScaffoldingModel(model));
//   if(models.isEmpty) {
//     return null;
//   } else {
//     final listPage = ScaffoldingListPageBuilder(models);
//     final detailPages = models.map((model) => ScaffoldingDetailPageBuilder(model, models));
//
//     return '''
//         ${imports.join('\n')}
//         ${listPage.build()}
//         ${detailPages.map((scaffoldingModel) => scaffoldingModel.build()).join('\n')}
//       ''';
//   }
// }
