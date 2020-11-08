import 'package:oobium_client_gen/src2/model_builder.dart';
import 'package:oobium_client_gen/src2/schema.dart';

// String generateInitializersLibrary(Schema schema, String modelsImport) {
//   final imports = <String>[
//     modelsImport,
//     "import 'package:oobium_common/oobium_common.dart';",
//   ].toSet().toList()..sort();
//
//   final initializers = InitializersBuilder(imports: imports, models: schema.models);
//
//   return initializers.build();
// }

String generateModelsLibrary(Schema schema) {
  final imports = <String>[
    ...schema.imports,
    "import 'package:oobium_common/oobium_common.dart';",
  ].toSet().toList()..sort();

  final dbname = '${schema.name[0].toUpperCase()}${schema.name.substring(1)}Data';
  final models = schema.models.map((model) => ModelBuilder(model));

  return '''
      ${imports.join('\n')}
      
      class $dbname extends Database {
        $dbname(String path) : super(path, [
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
//     "import 'package:oobium_client/oobium_client.dart';",
//     "import 'package:oobium_common/oobium_common.dart';",
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
