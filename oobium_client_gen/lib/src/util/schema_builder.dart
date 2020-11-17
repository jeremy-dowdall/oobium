import 'package:oobium_client_gen/src/util/model.dart';
import 'package:oobium_client_gen/src/util/model_field.dart';
import 'package:oobium_client_gen/src/util/schema.dart';
import 'package:oobium_client_gen/src/util/schema_library.dart';
import 'package:oobium_common/oobium_common.dart';

enum LibraryType { builders, models, scaffolding }

class SchemaBuilder {
  final SchemaLibrary library;
  SchemaBuilder(this.library);

  Schema build() {
    String owner = getOwnerType();
    List<Model> models = getModels(owner);
    expandModels(models);
    linkModels(models.expand((model) => model.all).toList());
    return Schema(imports, models);
  }

  List<String> get imports {
    final imports = <String, List<String>>{};
    final fields = library.models.expand((m) => m.fields.where((f) => f.isImportedType));
    for(var field in fields) {
      imports.putIfAbsent(field.importPackage, () => []).add(field.importTypeName);
    }
    return imports.keys.map((k) => "import '$k' show ${imports[k].join(', ')};").toList();
  }

  String getOwnerType() {
    final models = library.models.where((m) => m.isOwner);
    if(models.isEmpty) {
      throw FormatException('no owner type found (use "owner" option to specify)');
    }
    if(models.length > 1) {
      throw FormatException('only 1 owner type (designated by "owner" option) allowed per library');
    }
    return models.first.type;
  }

  List<Model> getModels(String owner) {
    return library.models.map((m) => Model(
      scaffold: m.isScaffold,
      owner: owner,
      type: m.type,
      fields: m.fields.map((f) => ModelField(
        metadata: f.options,
        type: f.type,
        name: f.name
      )).toList())
    ).toList();
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
