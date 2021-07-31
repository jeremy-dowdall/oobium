import 'package:collection/collection.dart';
import 'package:oobium_datastore_gen/src/model.dart';

class SchemaParser {
  Iterable<String> lines;
  SchemaParser(this.lines);

  Schema? parse() {
    final elements = SchemaElements.load(lines);
    return Schema(imports(elements), parts(elements), models(elements));
  }

  List<String> imports(SchemaElements elements) {
    final imports = <String, Set<String>>{};
    elements._imports.forEach((import) {
      final importPackage = import.from;
      if(importPackage != null) {
        imports.putIfAbsent(importPackage, () => {}).add(import.name);
      }
    });
    final fields = elements.models.expand((m) => m.fields.where((f) => f.isImportedType));
    for(var field in fields) {
      final importPackage = field.importPackage;
      if(importPackage != null) {
        imports.putIfAbsent(importPackage, () => {}).add(field.importTypeName);
      }
    }
    return imports.entries.map((e) => "import '${e.key}' show ${e.value.sorted((a,b) => a.compareTo(b)).join(', ')};").toList();
  }

  List<String> parts(SchemaElements elements) {
    return elements._parts.map((p) {
      return 'part \'${p.name}\';';
    }).toList();
  }

  List<Model> models(SchemaElements elements) {
    return elements.models.map((m) => Model(
        imports: elements._imports,
        options: m.options,
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
  final List<String> parts;
  final List<Model> models;
  Schema(this.imports, this.parts, this.models);
}

class SchemaElements {

  final _imports = <SchemaImport>[];
  final _parts = <SchemaPart>[];
  final _models = <SchemaModel>[];
  SchemaElements();

  Iterable<SchemaModel> get extensions => _models.where((e) => e.isExtension);
  Iterable<SchemaModel> get models => _models.where((e) => e.isModel);

  bool hasModel(String type) => _models.any((e) => e.isModel && e.type == type);

  static SchemaElements load(Iterable<String> lines) {
    final library = SchemaElements();

    List<int> indents = [];
    SchemaImport? import;
    SchemaModel? model;
    List<SchemaField>? fields;
    List<String>? options;
    for(final line in lines.filtered) {
      final start = line.indexOf(RegExp(r'\S'));
      if(start == -1) { // blank lines do nothing
        continue;
      }
      else if(start == 0) { // new element
        indents = [0];
        model = null;
        import = null;
        fields = null;
        options = null;
        if(line.startsWith('import ')) {
          final name = line.substring(7).trim();
          library._imports.add(
            import = SchemaImport(library, name)
          );
        }
        else if(line.startsWith('part ')) {
          final name = line.substring(5).trim();
          library._parts.add(
            SchemaPart(library, name)
          );
        }
        else {
          final parts = line.split(RegExp(r'[\(\)]'));
          final name = parts[0].split('<')[0];
          final type = parts[0].split('(')[0];
          library._models.add(
            model = SchemaModel(library, name, type,
              (parts.length > 1) ? parts[1].split(RegExp(r',\s*')) : []
            )
          );
        }
      }
      else if(start == indents.last) { // another of whatever the last was
        if(options != null) {
          addOption(line, options);
        }
        else if(fields != null) {
          addField(line, fields);
        }
        else {
          throw '? at line: $line';
        }
      }
      else if(start > indents.last) { // new element, field or option
        indents.add(start);
        if(options != null) {
          throw 'invalid indent, line: $line';
        }
        else if(fields != null) {
          options = addOption(line, fields.last.options);
        }
        else if(model != null) {
          fields = addField(line, model._fields);
        }
        else if(import != null) {
          options = addOption(line, import.options);
        }
      }
      else { // start < indent : finish, parse if line is not blank
        while(indents.isNotEmpty && start < indents.last) {
          indents.removeLast();
          if(options != null) {
            options = null;
          }
          else if(fields != null) {
            fields = null;
          }
          if(indents.isNotEmpty && start == indents.last) {
            if(fields != null) {
              addField(line, fields);
            }
          }
        }
      }
    }
    return library;
  }

  static List<SchemaField> addField(String line, List<SchemaField> fields) {
    final matches = RegExp(r"\s+(\w+)\s+([<\w, >]+)(\?)?(=[\w\[\]\{\}']+)?(\(([^\)]+)\))?").firstMatch(line);
    if(matches != null) {
      final name = matches.group(1)!;
      final type = matches.group(2)!;
      final nullable = matches.group(3) == '?';
      final initializer = matches.group(4);
      fields.add(SchemaField(name, type, nullable, initializer,
          (matches.group(6) ?? '').split(RegExp(r',\s*'))
      ));
    }
    return fields;
  }

  static List<String> addOption(String line, List<String> options) {
    return options..add(line.trim().replaceFirst(' ', ':'));
  }
}

class SchemaImport {
  final SchemaElements library;
  final String name;
  final options = <String>[];

  SchemaImport(this.library, this.name);

  String? get from => value('from');
  String? get decoder => value('decode');
  String? get encoder => value('encode');

  bool has(String name) => options.any((o) => o.startsWith('$name:'));

  String? value(String name) => options
      .firstWhereOrNull((o) => o.startsWith('$name:'))
      ?.substring('$name:'.length);

  bool decodes(String type) => (name == type) && has('decode');
  bool encodes(String type) => (name == type) && has('encode');
}

class SchemaPart {
  final SchemaElements library;
  final String name;
  SchemaPart(this.library, this.name);
}

class SchemaModel {

  final SchemaElements library;
  final String name;
  final String type;
  final List<String> options;
  final _fields = <SchemaField>[];

  SchemaModel(this.library, this.name, this.type, this.options);

  List<SchemaField> get fields {
    List<SchemaField> fields = [];
    fields.addAll(_fields);
    for(var option in options) {
      final extension = library._models.firstWhereOrNull((e) => e.name == option);
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