import 'package:analyzer/dart/element/element.dart';
import 'package:oobium_client_gen/generators/util/model.dart';
import 'package:oobium_client_gen/generators/util/model_field.dart';
import 'package:oobium_client_gen/generators/util/model_visitor.dart';
import 'package:oobium_client_gen/generators/util/schema.dart';
import 'package:oobium_common/oobium_common.dart';
import 'package:source_gen/source_gen.dart';

enum LibraryType { builders, models, scaffolding }

class SchemaBuilder {
  final LibraryReader library;
  SchemaBuilder(this.library);

  Schema load() {
    if(isSchema) {
      String owner = loadOwner();
      List<Model> models = loadModels(owner);
      expandModels(models);
      linkModels(models.expand((model) => model.all).toList());
      return Schema(modelsImport, sourceImports, models);
    }
    return null;
  }

  bool get isSchema => library.classes.any((c) => c.isModel);

  String get modelsImport => library.element.source.uri.toString().replaceFirst('.schema.dart', '.schema.models.dart');
  List<String> get sourceImports => library.element.imports.map((e) => e.uri).where((e) => e != 'package:oobium_client/oobium_client_annotations.dart').toList();

  String loadOwner() {
    final classes = library.classes.where((c) => c.metadata.any((meta) => meta.element.name == 'owner'));
    if(classes.isEmpty) {
      throw FormatException('no owner type found (use @owner instead of @model to specify)');
    }
    if(classes.length > 1) {
      throw FormatException('only 1 owner type (designated by @owner) allowed per library');
    }
    return TypeVisitor.visit(classes.first).type;
  }

  List<Model> loadModels(String owner) {
    return library.classes.where((c) => c.isModel).map((c) => ModelVisitor.visit(owner, c).model).toList();
  }

  void linkModels(List<Model> models) {
    models.forEach((model) {
      model.fields.forEach((field) {
        if(field.isLink) {
          field.linkedModel = _findLinkedModelForLink(field, models);
        }
        if(field.isHasMany) {
          field.linkedModel = _findLinkedModelForHasMany(field, models);
          field.linkedField = _findLinkedFieldForHasMany(field);
        }
      });
    });
  }

  void expandModels(List<Model> models) {
    models.forEach((model) {
      if(model.isGeneric) {
        models.forEach((m) {
          if(m.fields.any((f) => f.isHasMany && f.rawTypeArgument == model.name)) {
            model.expandWith(m);
          }
        });
      }
    });
  }

  Model _findLinkedModelForLink(ModelField field, List<Model> models) {
    if(field.isGeneric) {
      return null;
    }
    var linkedModelName = field.rawTypeArgument;
    var potentials = models.where((model) => model.name == linkedModelName).toList();
    if(potentials.isEmpty) {
      return Model.virtual(field.typeArgument);
    }
    if(potentials.length > 1) {
      // found multiples, check for a concrete match
      final linkedModelType = '$linkedModelName<${field.model.name}>';
      final concretes = potentials.where((model) => model.type == linkedModelType).toList();
      if(concretes.isEmpty) {
        // no concrete match found, fall back to the generic
        final generics = potentials.where((model) => model.isGeneric).toList();
        if(generics.isEmpty) {
          throw Exception('could not find linkedModel for ${field.model.type}.${field.name} -> $linkedModelType (sources: ${models.map((m) => m.type).join(', ')})');
        }
        if(generics.length > 1) {
          throw Exception('ambiguous linkedModel for ${field.model.type}.${field.name} -> $linkedModelType (found: ${potentials.map((m) => m.type).join(', ')})');
        }
        // return Model.virtual('${generics[0].name}<${field.model.name}>');
        return generics[0].parameterized(field.model.name);
      }
      if(concretes.length > 1) {
        throw Exception('ambiguous linkedModel for ${field.model.type}.${field.name} -> $linkedModelType (found: ${potentials.map((m) => m.type).join(', ')})');
      }
      return concretes[0];
    }
    return potentials[0];
  }

  Model _findLinkedModelForHasMany(ModelField field, List<Model> models) {
    if(field.model.isGeneric && field.isGeneric) {
      return Model.virtual(field.typeParameter);
    }
    var linkedModelName = field.rawTypeArgument;
    var linkedModels = models.where((model) => model.name == linkedModelName).toList();
    if(linkedModels.isEmpty) {
      throw Exception('could not find linkedModel for ${field.model.type}.${field.name} -> $linkedModelName (sources: ${models.map((m) => m.type).join(', ')})');
    }
    if(linkedModels.length > 1) {
      final linkedModelType = '$linkedModelName<${field.model.name}>';
      linkedModels = models.where((model) => model.type == linkedModelType).toList();
      if(linkedModels.isEmpty) {
        throw Exception('could not find linkedModel for ${field.model.type}.${field.name} -> $linkedModelType (sources: ${models.map((m) => m.type).join(', ')})');
      }
      if(linkedModels.length > 1) {
        throw Exception('ambiguous linkedModel for ${field.model.type}.${field.name} -> $linkedModelType (found: ${linkedModels.map((m) => m.type).join(', ')})');
      }
    }
    return linkedModels[0];
  }

  ModelField _findLinkedFieldForHasMany(ModelField field) {
    final linkedModel = field.linkedModel;
    if(linkedModel == null) {
      throw Exception('cannot find linkedField unless linkedModel is set');
    }
    final modelName = field.model.name;
    // Foo.HasMany<Bar> -> Link<Foo>
    List<ModelField> linkedFields = linkedModel.fields.where((field) => field.isLink && field.typeArgument == modelName).toList();
    if(linkedFields.isEmpty) {
      // did not find Link<Foo>; check generics
      if(linkedModel.isGeneric) {
        // Foo.HasMany<Bar> -> Link<P>
        final typeParam = linkedModel.typeParameter;
        linkedFields = linkedModel.fields.where((field) => field.isLink && field.typeParameter == typeParam).toList();
        if(linkedFields.length == 1) {
          return ModelField.virtual(type: 'Link<${modelName}>', name: linkedFields[0].name);
        }
      }
      // still no Link<Foo>; check if implied field is available
      String impliedFieldName = modelName.varName;
      if(linkedModel.fields.any((field) => field.name == impliedFieldName)) {
        // nope, implied field is taken - exit
        throw Exception('could not find linkedField for $modelName.${field.name} -> ${linkedModel.type}.<missing>');
      }
      // implied field is available - return as a virtual field
      return ModelField.virtual(type: 'Link<${modelName}>', name: impliedFieldName);
    }
    if(linkedFields.length > 1) {
      throw Exception('ambiguous linkedField for $modelName.${field.name} -> ${linkedModel.type}.<${linkedFields.map((f) => f.name).join('|')}>');
    }
    return linkedFields[0];
  }
}

extension _ClassElementExt on ClassElement {
  bool get isModel => metadata.any((meta) => meta.element.name == 'model' || meta.element.name == 'owner');
}
