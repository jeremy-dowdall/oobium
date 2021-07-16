import 'package:collection/collection.dart';
import 'package:oobium_datastore_gen/src/model.dart';
import 'package:xstring/xstring.dart';

class SchemaParser {
  Iterable<String> lines;
  SchemaParser(this.lines);

  Schema? parse() {
    final elements = SchemaElements.load(lines);
    return Schema(imports(elements), models(elements));
  }

  List<String> imports(SchemaElements elements) {
    final imports = <String, Set<String>>{};
    final fields = elements.models.expand((m) => m.fields.where((f) => f.isImportedType));
    for(var field in fields) {
      final importPackage = field.importPackage;
      if(importPackage != null) {
        imports.putIfAbsent(importPackage, () => {}).add(field.importTypeName);
      }
    }
    return imports.entries.map((e) => "import '${e.key}' show ${e.value.sorted((a,b) => a.compareTo(b)).join(', ')};").toList();
  }

  List<Model> models(SchemaElements elements) {
    return elements.models.map((m) => Model(
        scaffold: m.isScaffold,
        type: m.type,
        fields: m.fields.map((f) => ModelField(
            metadata: f.options,
            type: f.type,
            name: f.name,
            nullable: f.nullable,
            initializer: f.initializer,
            isModel: elements.hasModel(f.type)
        )).toList())
    ).toList();
  }
}

class Schema {
  final List<String> imports;
  final List<Model> models;
  Schema(this.imports, this.models);
}

class SchemaElements {

  final _elements = <SchemaElement>[];
  SchemaElements();

  Iterable<SchemaElement> get extensions => _elements.where((e) => e.isExtension);
  Iterable<SchemaElement> get models => _elements.where((e) => e.isModel);

  bool hasModel(String type) => _elements.any((e) => e.isModel && e.type == type);

  static SchemaElements load(Iterable<String> lines) {
    final library = SchemaElements();

    SchemaElement? element;
    for(final line in lines.filtered) {
      if(line.isBlank) {
        continue;
      }
      if(line.startsWith(RegExp(r'\s+'))) {
        if(element != null) {
          final matches = RegExp(r"\s+(\w+)\s+([<\w, >]+)(\?)?(=[\w\[\]\{\}']+)?(\(([^\)]+)\))?").firstMatch(line);
          if(matches != null) {
            final name = matches.group(1)!;
            final type = matches.group(2)!;
            final nullable = matches.group(3) == '?';
            final initializer = matches.group(4);
            final options = (matches.group(6) ?? '').split(RegExp(r',\s*'));
            element._fields.add(SchemaField(name, type, nullable, initializer, options));
          }
        }
      } else {
        final parts = line.split(RegExp(r'[\(\)]'));
        final name = parts[0].split('<')[0];
        final type = parts[0].split('(')[0];
        final options = (parts.length > 1) ? parts[1].split(RegExp(r',\s*')) : <String>[];
        element = SchemaElement(library, name, type, options);
      }
    }
    return library;
  }
}

class SchemaElement {

  final SchemaElements library;
  final String name;
  final String type;
  final List<String> options;
  final _fields = <SchemaField>[];

  SchemaElement(this.library, this.name, this.type, this.options) {
    library._elements.add(this);
  }

  List<SchemaField> get fields {
    List<SchemaField> fields = [];
    fields.addAll(_fields);
    for(var option in options) {
      final extension = library._elements.firstWhereOrNull((e) => e.name == option);
      if(extension != null) {
        fields.addAll(extension.fields);
      }
    }
    return fields;
  }

  bool get isExtension => RegExp(r'^[a-z].*$').hasMatch(name);
  bool get isNotExtension => !isExtension;

  bool get isModel => RegExp(r'^[A-Z].*$').hasMatch(name);
  bool get isNotModel => !isModel;

  bool get isScaffold => options.contains('scaffold');
  bool get isNotScaffold => !isScaffold;

  @override
  String toString() => '$type(${options.join(', ')})${fields.isNotEmpty ? '\n  ${fields.join('\n ')}' : ''}';
}

class SchemaField {
  final String name;
  final String type;
  final bool nullable;
  final String? initializer;
  final List<String> options;
  SchemaField(this.name, this.type, this.nullable, this.initializer, this.options);

  bool get isImportedType => importPackage != null;
  bool get isNotImportedType => !isImportedType;

  String? get importPackage => options.firstWhereOrNull((o) => o.startsWith('package:'));

  String get importTypeName {
    var name = type.split('<')[0];
    if(name == 'Link' || name == 'ChildLink') {
      name = type.substring(name.length + 1, type.length - 1);
    }
    return name;
  }

  @override
  String toString() => '$name $type(${options.join(', ')})';
}

extension XStringIterable on Iterable<String> {
  Iterable<String> get filtered => this.map((line) => line.split('//')[0].trimRight());
}