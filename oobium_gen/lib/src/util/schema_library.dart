class SchemaLibrary {
  final _elements = <SchemaElement>[];

  Iterable<SchemaElement> get extensions => _elements.where((e) => e.isExtension);
  Iterable<SchemaElement> get models => _elements.where((e) => e.isModel);

  static SchemaLibrary parse(List<String> lines) {
    final library = SchemaLibrary();
    SchemaElement element;
    for(var line in lines) {
      if(line.trim().isEmpty || line.startsWith('//')) {
        continue;
      }
      if(line.startsWith(' ')) {
        final matches = RegExp(r'\s+(\w+)\s+([<\w>]+)(\(([^\)]+)\))?').firstMatch(line);
        final name = matches.group(1);
        final type = matches.group(2);
        final options = (matches.group(4) ?? '').split(RegExp(r',\s*'));
        element._fields.add(SchemaField(name, type, options));
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

  final SchemaLibrary library;
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
      final extension = library._elements.firstWhere((e) => e.name == option, orElse: () => null);
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

  bool get isOwner => options.contains('owner');
  bool get isNotOwner => !isOwner;

  @override
  String toString() => '$type(${options.join(', ')})\n  ${fields.join('\n  ')}';
}

class SchemaField {
  final String name;
  final String type;
  final List<String> options;
  SchemaField(this.name, this.type, this.options);

  bool get isImportedType => importPackage != null;
  bool get isNotImportedType => !isImportedType;

  String get importPackage => options.firstWhere((o) => o.startsWith('package:'), orElse: () => null);

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
