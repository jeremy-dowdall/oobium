import 'package:oobium_datastore_gen/src/schema_parser.dart';
import 'package:xstring/xstring.dart';

enum LibraryType { builders, models, scaffolding }

class SchemaGenerator {

  final String library;
  SchemaGenerator._(this.library);

  factory SchemaGenerator.generate(String name, Schema schema) {
    final imports = <String>[
      ...schema.imports,
      "import 'package:oobium_datastore/oobium_datastore.dart';",
    ].toSet().toList()..sort();

    final dsName = '${name.camelCase}Data';
    final dsType = '${name.camelCase}Model';
    final dsPath = name.underscored;
    final models = schema.models;

    final schemaLibrary =
      '${imports.join('\n')}'
      'class $dsName {'
        'final DataStore _ds;'
        '$dsName(String path, {String? isolate}) : _ds = DataStore('
          '\'\$path/$dsPath\','
          'isolate: isolate,'
          'builders: [${models.map((m) => '(data) => ${m.name}.fromJson(data)').join(',')}],'
          'indexes: [${models.where((m) => m.isIndexed).map((m) => 'DataIndex<${m.name}>(toKey: (m) => m.id)').join(',')}]'
        ');'
        'Future<$dsName> open({'
          'int version=1, Stream<DataRecord> Function(UpgradeEvent event)? onUpgrade'
        '}) => _ds.open(version: version, onUpgrade: onUpgrade).then((_) => this);'
        'Future<void> flush() => _ds.flush();'
        'Future<void> close() => _ds.close();'
        'Future<void> destroy() => _ds.destroy();'
        'bool get isEmpty => _ds.isEmpty;'
        'bool get isNotEmpty => _ds.isNotEmpty;'
        '${models.map((m) => '${m.name}? get${m.name}(${m.idType}? id, {${m.name}? Function()? orElse}) => _ds.get<${m.name}>(id, orElse: orElse);').join()}'
        '${models.map((m) => 'Iterable<${m.name}> get${m.name.plural}() => _ds.getAll<${m.name}>();').join()}'
        '${models.map((m) => 'Iterable<${m.name}> find${m.name.plural}(${m.copyFields}) => _ds.getAll<${m.name}>().where((m) => ${m.finderFields('m')});').join()}'
        'T put<T extends $dsType>(T model) => _ds.put<T>(model);'
        'List<T> putAll<T extends $dsType>(Iterable<T> models) => _ds.putAll<T>(models);'
        '${models.map((m) => '${m.name} put${m.name}(${m.constructorFields}) => _ds.put(${m.name}(${m.constructorParams}));').join()}'
        'T remove<T extends $dsType>(T model) => _ds.remove<T>(model);'
        'List<T> removeAll<T extends $dsType>(Iterable<T> models) => _ds.removeAll<T>(models);'
        '${models.map((m) => 'Stream<${m.name}?> stream${m.name}(${m.idType} id) => _ds.stream<${m.name}>(id);').join()}'
        '${models.map((m) => 'Stream<DataModelEvent<${m.name}>> stream${m.name.plural}({bool Function(${m.name} model)? where}) => _ds.streamAll<${m.name}>(where: where);').join()}'
        // '${models.map((m) => '${m.name}? remove${m.name}(String? id) => _ds.remove<${m.name}>(id);').join()}'
      '}'
      'abstract class $dsType extends DataModel {'
        '$dsType([Map<String, dynamic>? fields]) : super(fields);'
        '$dsType.copyNew($dsType original, Map<String, dynamic>? fields) : super.copyNew(original, fields);'
        '$dsType.copyWith($dsType original, Map<String, dynamic>? fields) : super.copyWith(original, fields);'
        '$dsType.fromJson(data, Set<String> fields, Set<String> modelFields, bool newId) : super.fromJson(data, fields, modelFields, newId);'
      '}'
      '${models.map((m) => m.compile(dsType)).join('\n')}'
    ;

    return SchemaGenerator._(schemaLibrary);
  }

}

extension StringX on String {
  String get plural => this + 's';
}
