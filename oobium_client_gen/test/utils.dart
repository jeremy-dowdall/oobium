import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:oobium_client_gen/generators/util/model_field.dart';
import 'package:oobium_client_gen/generators/util/model_visitor.dart';
import 'package:mockito/mockito.dart';
import 'package:oobium_client_gen/generators/util/schema.dart';
import 'package:oobium_client_gen/generators/util/schema_builder.dart';
import 'package:source_gen/source_gen.dart';

export 'package:oobium_common/oobium_common.dart';

Schema schemaDef(List<ClassDef> models) {
  return SchemaBuilder(libraryReader(models)).load();
}

ClassDef classDef(String model, List<String> fields) {
  return ClassDef(model, fields: fields.map((e) => FieldDef(e)).toList());
}

class ClassDef {
  final List<String> meta;
  final String type;
  final List<FieldDef> fields;
  ClassDef(String def, {List<FieldDef> fields}) :
    meta = def.split(' ').where((s) => s.startsWith('@')).map((s) => s.substring(1)).toList(),
    type = def.split(' ').firstWhere((s) => !s.startsWith('@')),
    fields = fields ?? []
  ;
}
class FieldDef {
  final List<String> meta;
  final String type;
  final String name;
  FieldDef(String def) :
    meta = def.split(' ').where((s) => s.startsWith('@')).map((s) => s.substring(1)).toList(),
    type = def.split(' ').firstWhere((s) => !s.startsWith('@')),
    name = def.split(' ').last
  ;
}

LibraryReader libraryReader(List<ClassDef> definitions) {
  final classes = definitions.map((d) => classElement(d)).toList();
  final library = TestLibraryReader();
  final element = TestLibraryElement();
  final source = TestSource();
  when(library.classes).thenReturn(classes);
  when(library.element).thenReturn(element);
  when(element.source).thenReturn(source);
  when(element.imports).thenReturn([]);
  when(source.uri).thenReturn(Uri.parse('package:oobium_client_gen/utils.dart'));
  return library;
}

ClassElement classElement(ClassDef classDef) {
  final elements = classDef.meta.map((m) => element(m)).toList();
  final metadata = elements.map((e) => annotation(e)).toList();
  final classElement = TestClassElement();
  when(classElement.metadata).thenReturn(metadata);
  when(classElement.visitChildren(any)).thenAnswer((i) {
    final visitor = i.positionalArguments[0];
    if(visitor is TypeVisitor) {
      visitor.type = classDef.type;
    }
    if(visitor is ModelVisitor) {
      visitor.type = classDef.type;
      visitor.fields = classDef.fields.map((fieldDef) => ModelField(
        metadata: fieldDef.meta,
        type: fieldDef.type,
        name: fieldDef.name
      )).toList();
    }
  });
  return classElement;
}

ElementAnnotation annotation(Element element) {
  final annotation = TestElementAnnotation();
  when(annotation.element).thenReturn(element);
  return annotation;
}

Element element(String name) {
  final element = TestElement();
  when(element.name).thenReturn(name);
  return element;
}

class TestElement extends Mock implements Element { }
class TestElementAnnotation extends Mock implements ElementAnnotation { }
class TestClassElement extends Mock implements ClassElement { }
class TestLibraryElement extends Mock implements LibraryElement { }
class TestLibraryReader extends Mock implements LibraryReader { }
class TestSource extends Mock implements Source { }
