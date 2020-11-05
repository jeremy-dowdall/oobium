import 'package:build/build.dart';
import 'package:oobium_client_gen/generators/initializers_library_generator.dart';
import 'package:oobium_client_gen/generators/models_library_generator.dart';
import 'package:oobium_client_gen/generators/scaffolding_library_generator.dart';
import 'package:source_gen/source_gen.dart';

Builder buildersLibraryBuilder(BuilderOptions options) =>
    LibraryBuilder(InitializersLibraryGenerator(), generatedExtension: '.initializers.dart');

Builder modelsLibraryBuilder(BuilderOptions options) =>
    LibraryBuilder(ModelsLibraryGenerator(), generatedExtension: '.models.dart');

Builder scaffoldingLibraryBuilder(BuilderOptions options) =>
    LibraryBuilder(ScaffoldingLibraryGenerator(), generatedExtension: '.scaffolding.dart');
