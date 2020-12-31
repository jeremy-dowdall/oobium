
import 'package:oobium_gen/src/util/initializers_builder.dart';
import 'package:oobium_gen/src/util/model_builder.dart';
import 'package:oobium_gen/src/util/scaffolding_detail_page_builder.dart';
import 'package:oobium_gen/src/util/scaffolding_list_page_builder.dart';
import 'package:oobium_gen/src/util/scaffolding_model.dart';
import 'package:oobium_gen/src/util/schema.dart';

String generateInitializersLibrary(Schema schema, String modelsImport) {
  final imports = <String>[
    modelsImport,
    "import 'package:oobium/oobium.dart';",
    "import 'package:oobium_client/oobium_client.dart';",
  ].toSet().toList()..sort();

  final initializers = InitializersBuilder(imports: imports, models: schema.models);

  return initializers.build();
}

String generateModelsLibrary(Schema schema) {
  final imports = <String>[
    ...schema.imports,
    "import 'package:oobium_client/oobium_client.dart';",
    "import 'package:oobium/oobium.dart';",
  ].toSet().toList()..sort();

  final models = schema.models.map((model) => ModelBuilder(model));

  return '''
      ${imports.join('\n')}
      
      ${models.map((model) => model.build()).join('\n')}
    ''';
}

String generateScaffoldingLibrary(Schema schema, String modelsImport) {
  final imports = <String>[
    modelsImport,
    ...schema.imports,
    "import 'dart:async';",
    "import 'package:flutter/material.dart';",
    "import 'package:oobium_client/oobium_client.dart';",
    "import 'package:oobium/oobium.dart';",
    "import 'package:provider/provider.dart';",
  ].toSet().toList()..sort();

  final models = schema.models.where((model) => model.scaffold).expand((m) => m.expanded).map((model) => ScaffoldingModel(model));
  if(models.isEmpty) {
    return null;
  } else {
    final listPage = ScaffoldingListPageBuilder(models);
    final detailPages = models.map((model) => ScaffoldingDetailPageBuilder(model, models));

    return '''
        ${imports.join('\n')}
        ${listPage.build()}
        ${detailPages.map((scaffoldingModel) => scaffoldingModel.build()).join('\n')}
      ''';
  }
}
