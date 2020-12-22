import 'package:analyzer/dart/element/element.dart' ;
import 'package:analyzer/dart/element/visitor.dart';
import 'package:oobium_client_gen/src/util/model.dart';
import 'package:oobium_client_gen/src/util/model_field.dart';

class TypeVisitor extends SimpleElementVisitor {

  TypeVisitor();
  TypeVisitor.visit(ClassElement element) { element.visitChildren(this); }

  String type;

  @override
  visitConstructorElement(ConstructorElement element) {
    type = element.enclosingElement.thisType.toString();
  }
}

class ModelVisitor extends SimpleElementVisitor {

  Model model;
  bool scaffold;
  String owner;
  String type;
  List<ModelField> fields = [];

  ModelVisitor();
  ModelVisitor.visit(String owner, ClassElement element) {
    element.visitChildren(this);
    model = Model(
      scaffold: element.metadata.any((meta) => meta.element.name == 'scaffold'),
      owner: owner,
      type: type,
      fields: fields
    );
  }

  @override
  visitConstructorElement(ConstructorElement element) {
    type = element.enclosingElement.thisType.toString().replaceAll('<dynamic>', '');
    element.enclosingElement.interfaces.forEach((e) => e.element.fields.forEach((f) => visitFieldElement(f)));
  }

  @override
  visitFieldElement(FieldElement element) {
    fields.add(ModelField(
      metadata: element.metadata.map((meta) => meta.element.name).toList(),
      type: element.type.toString().replaceAll('<dynamic>', ''),
      name: element.name,
    ));
  }
}
