import 'package:oobium_client_gen/generators/util/scaffolding_model.dart';
import 'package:oobium_client_gen/generators/util/scaffolding_detail_page_builder.dart';
import 'package:oobium_client_gen/generators/util/scaffolding_list_page_builder.dart';
import 'package:oobium_client_gen/generators/util/schema.dart';
import 'package:oobium_client_gen/generators/util/schema_generator.dart';

class ScaffoldingLibraryGenerator extends SchemaGenerator {

  @override
  generateLibrary(Schema schema) {
    final imports = <String>[
      'dart:async',
      ...schema.sourceImports,
      'package:flutter/material.dart',
      'package:oobium_client/oobium_client.dart',
      'package:provider/provider.dart',
      schema.modelsImport,
    ].toSet().toList()..sort();

    final models = schema.models.where((model) => model.scaffold).expand((m) => m.expanded).map((model) => ScaffoldingModel(model));
    final listPage = ScaffoldingListPageBuilder(models);
    final detailPages = models.map((model) => ScaffoldingDetailPageBuilder(model, models));

    return '''
      ${imports.map((import) => 'import \'$import\';').join('\n')}
      ${listPage.build()}
      ${detailPages.map((scaffoldingModel) => scaffoldingModel.build()).join('\n')}
    ''';
  }
}
