import 'package:oobium_client_gen/generators/util/schema_builder.dart';
import 'package:oobium_common_test/oobium_common_test.dart';
import 'package:test/test.dart';
import 'utils.dart';

void main() {
  group('test isSchema', () {
    test('with owner', () {
      final library = libraryReader([ClassDef('@owner Foo')]);
      final builder = SchemaBuilder(library);
      expect(builder.isSchema, isTrue);
    });

    test('with model', () {
      final library = libraryReader([ClassDef('@model Foo')]);
      final builder = SchemaBuilder(library);
      expect(builder.isSchema, isTrue);
    });

    test('without owner or model (empty metadata)', () {
      final library = libraryReader([ClassDef('Bar')]);
      final builder = SchemaBuilder(library);
      expect(builder.isSchema, isFalse);
    });

    test('without owner or model (unknown metadata)', () {
      final library = libraryReader([ClassDef('@unknown Bar')]);
      final builder = SchemaBuilder(library);
      expect(builder.isSchema, isFalse);
    });
  });

  group('test loadOwner', () {
    test('without owner throws exception', () {
      final library = libraryReader([ClassDef('@model Foo')]);
      final builder = SchemaBuilder(library);
      expectError(() => builder.loadOwner(), 'no owner type found (use @owner instead of @model to specify)');
    });

    test('with 2 owners throws exception', () {
      final library = libraryReader([ClassDef('@owner Foo'), ClassDef('@owner Bar')]);
      final builder = SchemaBuilder(library);
      expectError(() => builder.loadOwner(), 'only 1 owner type (designated by @owner) allowed per library');
    });

    test('with owner', () {
      final library = libraryReader([ClassDef('@owner Foo')]);
      final builder = SchemaBuilder(library);
      expect(builder.loadOwner(), 'Foo');
    });

    test('with owner and then model', () {
      final library = libraryReader([ClassDef('@owner Foo'), ClassDef('@model Bar')]);
      final builder = SchemaBuilder(library);
      expect(builder.loadOwner(), 'Foo');
    });

    test('with model and then owner', () {
      final library = libraryReader([ClassDef('@model Foo'), ClassDef('@owner Bar')]);
      final builder = SchemaBuilder(library);
      expect(builder.loadOwner(), 'Bar');
    });
  });

  group('test loadModels', () {
    test('set owner', () {
      final library = libraryReader([
        ClassDef('@model Foo')
      ]);
      final models = SchemaBuilder(library).loadModels('TestOwner');
      expect(models.length, 1);
      expect(models[0].owner, 'TestOwner');
    });

    test('Foo, single', () {
      final library = libraryReader([
        ClassDef('@model Foo')
      ]);
      final models = SchemaBuilder(library).loadModels('TestOwner');
      expect(models.length, 1);
      expect(models[0].type, 'Foo');
      expect(models[0].name, 'Foo');
      expect(models[0].isVirtual, isFalse);
      expect(models[0].isGeneric, isFalse);
    });

    test('Foo & Bar, multiple', () {
      final library = libraryReader([
        ClassDef('@model Foo'),
        ClassDef('@model Bar'),
      ]);
      final models = SchemaBuilder(library).loadModels('TestOwner');
      expect(models.length, 2);
      expect(models[0].type, 'Foo');
      expect(models[0].name, 'Foo');
      expect(models[0].isVirtual, isFalse);
      expect(models[0].isGeneric, isFalse);
      expect(models[1].type, 'Bar');
      expect(models[1].name, 'Bar');
      expect(models[1].isVirtual, isFalse);
      expect(models[1].isGeneric, isFalse);
    });

    test('Foo<P>, generic', () {
      final library = libraryReader([
        ClassDef('@model Foo<P>'),
      ]);
      final models = SchemaBuilder(library).loadModels('TestOwner');
      expect(models.length, 1);
      expect(models[0].type, 'Foo<P>'); // TODO ???
      expect(models[0].name, 'Foo');
      expect(models[0].isVirtual, isFalse);
      expect(models[0].isGeneric, isTrue);
      expect(models[0].typeParameter, 'P');
      expect(models[0].typeArgument, isNull);
    });

    test('Foo.Link<Bar>, virtual', () {
      final library = libraryReader([
        ClassDef('@model Foo', fields: [FieldDef('Link<Bar> bar')]),
      ]);
      final models = SchemaBuilder(library).loadModels('TestOwner');
      expect(models.length, 1);
      expect(models[0].type, 'Foo');
      expect(models[0].name, 'Foo');
      expect(models[0].isVirtual, isFalse);
      expect(models[0].isGeneric, isFalse);
    });
  });

  group('test loadModels, fields', () {
    test('Foo:String', () {
      final library = libraryReader([
        ClassDef('@model Foo', fields: [FieldDef('String name')])
      ]);
      final models = SchemaBuilder(library).loadModels('TestOwner');
      expect(models.length, 1);
      expect(models[0].fields.length, 1);
      expect(models[0].fields[0].model, models[0]);
      expect(models[0].fields[0].type, 'String');
      expect(models[0].fields[0].name, 'name');
      expect(models[0].fields[0].isString, isTrue);
      expect(models[0].fields[0].isResolve, isFalse);
    });

    test('Foo:Link<Bar>, virtual field', () {
      final library = libraryReader([
        ClassDef('@model Foo', fields: [FieldDef('Link<Bar> bar')]),
      ]);
      final models = SchemaBuilder(library).loadModels('TestOwner');
      expect(models?.length, 1);
      expect(models[0].fields?.length, 1);
      expect(models[0].fields[0].model.type, 'Foo');
      expect(models[0].fields[0].type, 'Link<Bar>');
      expect(models[0].fields[0].rawType, 'Link');
      expect(models[0].fields[0].typeArgument, 'Bar');
      expect(models[0].fields[0].typeParameter, null);
      expect(models[0].fields[0].name, 'bar');
      expect(models[0].fields[0].isLink, isTrue);
      expect(models[0].fields[0].isResolve, isFalse);
      expect(models[0].fields[0].isGeneric, isFalse);
      expect(models[0].fields[0].isParameterized, isTrue);
    });

    test('Foo:Link<Bar>, resolved virtual field', () {
      final library = libraryReader([
        ClassDef('@model Foo', fields: [FieldDef('@resolve Link<Bar> bar')]),
      ]);
      final models = SchemaBuilder(library).loadModels('TestOwner');
      expect(models?.length, 1);
      expect(models[0].fields?.length, 1);
      expect(models[0].fields[0].model.type, 'Foo');
      expect(models[0].fields[0].type, 'Link<Bar>');
      expect(models[0].fields[0].rawType, 'Link');
      expect(models[0].fields[0].typeArgument, 'Bar');
      expect(models[0].fields[0].typeParameter, null);
      expect(models[0].fields[0].name, 'bar');
      expect(models[0].fields[0].isLink, isTrue);
      expect(models[0].fields[0].isResolve, isTrue);
      expect(models[0].fields[0].isGeneric, isFalse);
      expect(models[0].fields[0].isParameterized, isTrue);
    });

    test('Foo<P>:Link<P>, generic field', () {
      final library = libraryReader([
        ClassDef('@model Foo<P>', fields: [FieldDef('Link<P> bar')]),
      ]);
      final models = SchemaBuilder(library).loadModels('TestOwner');
      expect(models?.length, 1);
      expect(models[0].fields?.length, 1);
      expect(models[0].fields[0].model.type, 'Foo<P>');
      expect(models[0].fields[0].type, 'Link<P>');
      expect(models[0].fields[0].rawType, 'Link');
      expect(models[0].fields[0].typeArgument, null);
      expect(models[0].fields[0].typeParameter, 'P');
      expect(models[0].fields[0].name, 'bar');
      expect(models[0].fields[0].isLink, isTrue);
      expect(models[0].fields[0].isResolve, isFalse);
      expect(models[0].fields[0].isGeneric, isTrue);
      expect(models[0].fields[0].isParameterized, isFalse);
    });
  });

  group('test linkModels, Link', () {
    test('Foo:Link<Bar> -> Bar', () {
      final library = libraryReader([
        ClassDef('@model Foo', fields: [FieldDef('Link<Bar> bar')]),
        ClassDef('@model Bar')
      ]);
      final builder = SchemaBuilder(library);
      final models = builder.loadModels('TestOwner');
      builder.linkModels(models);
      expect(models.length, 2);
      expect(models[0].fields.length, 1);
      expect(models[0].fields[0].linkedModel, models[1]);
    });

    test('Foo:Link<Bar> -> Bar, virtual', () {
      final library = libraryReader([
        ClassDef('@owner Foo', fields: [FieldDef('Link<Bar> bar')])
      ]);
      final builder = SchemaBuilder(library);
      final models = builder.loadModels('TestOwner');
      builder.linkModels(models);
      expect(models.length, 1);
      expect(models[0].fields.length, 1);
      expect(models[0].fields[0].linkedModel, isNotNull);
      expect(models[0].fields[0].linkedModel.type, 'Bar');
      expect(models[0].fields[0].linkedModel.name, 'Bar');
      expect(models[0].fields[0].linkedModel.isVirtual, isTrue);
    });

    test('Foo:Link<Bar<Bat>> -> Bar<Bat>, virtual', () {
      final library = libraryReader([
        ClassDef('@model Foo', fields: [FieldDef('Link<Bar<Bat>> bar')])
      ]);
      final builder = SchemaBuilder(library);
      final models = builder.loadModels('TestOwner');
      builder.linkModels(models);
      expect(models.length, 1);
      expect(models[0].fields.length, 1);
      expect(models[0].fields[0].linkedModel, isNotNull);
      expect(models[0].fields[0].linkedModel.type, 'Bar<Bat>');
      expect(models[0].fields[0].linkedModel.name, 'Bar');
      expect(models[0].fields[0].linkedModel.isVirtual, isTrue);
    });

    test('Foo<P>:Link<P> -> null, generic', () {
      final library = libraryReader([
        ClassDef('@model Foo<P>', fields: [FieldDef('Link<P> bar')])
      ]);
      final builder = SchemaBuilder(library);
      final models = builder.loadModels('TestOwner');
      builder.linkModels(models);
      expect(models.length, 1);
      expect(models[0].fields.length, 1);
      expect(models[0].fields[0].linkedModel, isNull);
    });
  });

  group('test linkModels, HasMany', () {
    test('Foo.HasMany<Bar> -> throws missing linkedModel', () {
      final library = libraryReader([
        ClassDef('@model Foo', fields: [FieldDef('HasMany<Bar> bars')]),
      ]);
      final builder = SchemaBuilder(library);
      final models = builder.loadModels('TestOwner');
      expectError(() => builder.linkModels(models), 'could not find linkedModel for Foo.bars -> Bar (sources: Foo)');
    });

    test('Foo.HasMany<Bar> -> Bar.foo, implied', () {
      final library = libraryReader([
        ClassDef('@model Foo', fields: [FieldDef('HasMany<Bar> bars')]),
        ClassDef('@model Bar'),
      ]);
      final builder = SchemaBuilder(library);
      final models = builder.loadModels('TestOwner');
      builder.linkModels(models);
      expect(models.length, 2);
      expect(models[0].fields.length, 1);
      expect(models[0].fields[0].linkedModel, models[1]);
      expect(models[0].fields[0].linkedField, isNotNull);
      expect(models[0].fields[0].linkedField.model, models[1]);
      expect(models[0].fields[0].linkedField.type, 'Link<Foo>');
      expect(models[0].fields[0].linkedField.name, 'foo');
      expect(models[0].fields[0].linkedField.isVirtual, isTrue);
    });

    test('Foo.HasMany<Bar> -> throws missing linkedField', () {
      final library = libraryReader([
        ClassDef('@model Foo', fields: [FieldDef('HasMany<Bar> bars')]),
        ClassDef('@model Bar', fields: [FieldDef('String foo')]), // implied field is taken, and references something else
      ]);
      final builder = SchemaBuilder(library);
      final models = builder.loadModels('TestOwner');
      expectError(() => builder.linkModels(models), 'could not find linkedField for Foo.bars -> Bar.<missing>');
    });

    test('Foo.HasMany<Bar> -> Bar.foo', () {
      final library = libraryReader([
        ClassDef('@model Foo', fields: [FieldDef('HasMany<Bar> bars')]),
        ClassDef('@model Bar', fields: [FieldDef('Link<Foo> foo')]),
      ]);
      final builder = SchemaBuilder(library);
      final models = builder.loadModels('TestOwner');
      builder.linkModels(models);
      expect(models.length, 2);
      expect(models[0].fields.length, 1);
      expect(models[1].fields.length, 1);
      expect(models[0].fields[0].linkedModel, models[1]);
      expect(models[0].fields[0].linkedField, models[1].fields[0]);
    });

    test('Foo.HasMany<Bar> -> throws ambiguous linkedField', () {
      final library = libraryReader([
        ClassDef('@model Foo', fields: [FieldDef('HasMany<Bar> bars')]),
        ClassDef('@model Bar', fields: [FieldDef('Link<Foo> foo'), FieldDef('Link<Foo> alsoFoo')]),
      ]);
      final builder = SchemaBuilder(library);
      final models = builder.loadModels('TestOwner');
      expectError(() => builder.linkModels(models), 'ambiguous linkedField for Foo.bars -> Bar.<foo|alsoFoo>');
    });

    test('Foo.HasMany<Bat>|Bar.HasMany<Bat> -> Bat.foo|Bat.bar', () {
      final library = libraryReader([
        ClassDef('@model Foo', fields: [FieldDef('HasMany<Bat> bats')]),
        ClassDef('@model Bar', fields: [FieldDef('HasMany<Bat> bats')]),
        ClassDef('@model Bat', fields: [FieldDef('Link<Foo> foo'), FieldDef('Link<Bar> bar')]),
      ]);
      final builder = SchemaBuilder(library);
      final models = builder.loadModels('TestOwner');
      builder.linkModels(models);
      expect(models.length, 3);
      final fooBats = models[0].fields[0];
      final barBats = models[1].fields[0];
      final batFoo = models[2].fields[0];
      final batBar = models[2].fields[1];
      expect(fooBats.linkedField, batFoo);
      expect(barBats.linkedField, batBar);
      expect(batFoo.linkedField, isNull);
      expect(batBar.linkedField, isNull);
    });

    test('Foo.HasMany<Bat>|Bar.HasMany<Bat> -> Bat<Foo>.parent|Bat<Bar>.parent, generic', () {
      final library = libraryReader([
        ClassDef('@model Foo', fields: [FieldDef('HasMany<Bat> bats')]),
        ClassDef('@model Bar', fields: [FieldDef('HasMany<Bat> bats')]),
        ClassDef('@model Bat<P>', fields: [FieldDef('Link<P> parent')]),
      ]);
      final builder = SchemaBuilder(library);
      final models = builder.loadModels('TestOwner');
      builder.linkModels(models);
      expect(models.length, 3);
      final Foo = models[0], Bar = models[1], Bat = models[2];
      expect(Foo.fields[0].linkedModel, Bat);
      expect(Bar.fields[0].linkedModel, Bat);
      expect(Foo.fields[0].type, 'HasMany<Bat<Foo>>');
      expect(Bar.fields[0].type, 'HasMany<Bat<Bar>>');
      expect(Foo.fields[0].linkedField.type, 'Link<Foo>');
      expect(Foo.fields[0].linkedField.typeArgument, 'Foo');
      expect(Foo.fields[0].linkedField.name, 'parent');
      expect(Foo.fields[0].linkedField.isVirtual, isTrue);
      expect(Bar.fields[0].linkedField.type, 'Link<Bar>');
      expect(Bar.fields[0].linkedField.typeArgument, 'Bar');
      expect(Bar.fields[0].linkedField.name, 'parent');
      expect(Bar.fields[0].linkedField.isVirtual, isTrue);
      expect(Bat.fields[0].linkedField, isNull);
    });

    test('Foo.HasMany<Bat>|Bar.HasMany<Bat> -> Bat<Foo>.parent|Bat<Bar>.bar, generic', () {
      final library = libraryReader([
        ClassDef('@model Foo', fields: [FieldDef('HasMany<Bat> bats')]),
        ClassDef('@model Bar', fields: [FieldDef('HasMany<Bat> bats')]),
        ClassDef('@model Bat<P>', fields: [FieldDef('Link<P> parent'), FieldDef('Link<Bar> bar')]),
      ]);
      final builder = SchemaBuilder(library);
      final models = builder.loadModels('TestOwner');
      builder.linkModels(models);
      expect(models.length, 3);
      final Foo = models[0], Bar = models[1], Bat = models[2];
      expect(Foo.fields[0].linkedModel, Bat);
      expect(Bar.fields[0].linkedModel, Bat);
      expect(Foo.fields[0].type, 'HasMany<Bat<Foo>>');
      expect(Bar.fields[0].type, 'HasMany<Bat<Bar>>');
      expect(Foo.fields[0].linkedField.type, 'Link<Foo>');
      expect(Foo.fields[0].linkedField.typeArgument, 'Foo');
      expect(Foo.fields[0].linkedField.name, 'parent');
      expect(Foo.fields[0].linkedField.isVirtual, isTrue);
      expect(Bar.fields[0].linkedField, Bat.fields[1]);
      expect(Bat.fields[0].linkedField, isNull);
    });

    test('Foo.Link<Bar>|HasMany<Bar> -> Bar<Foo>|Bar<Foo>.parent', () {
      final library = libraryReader([
        ClassDef('@model Foo', fields: [FieldDef('Link<Bar<Foo>> bar'), FieldDef('HasMany<Bar> bars')]),
        ClassDef('@model Bar<P>', fields: [FieldDef('Link<P> parent')]),
      ]);
      final builder = SchemaBuilder(library);
      final models = builder.loadModels('TestOwner');
      builder.linkModels(models);
      expect(models.length, 2);
      final Foo = models[0], Bar = models[1];
      expect(Foo.fields[0].linkedModel, isNotNull);
      expect(Foo.fields[0].linkedModel.type, 'Bar<P>');
      expect(Foo.fields[0].linkedModel.name, 'Bar');
      expect(Foo.fields[0].linkedModel.isGeneric, isTrue);
      expect(Foo.fields[1].linkedField.type, 'Link<Foo>');
      expect(Foo.fields[1].linkedField.name, 'parent');
      expect(Foo.fields[1].linkedField.isVirtual, isTrue);
      expect(Bar.fields[0].linkedField, isNull);
    });

    test('Foo<P>.Link<P>|HasMany<Foo<P>> -> null|Link<Foo>', () { // TODO not quite right... ?
      final library = libraryReader([
        ClassDef('@model Foo<P>', fields: [FieldDef('Link<P> parent'), FieldDef('HasMany<Foo> children')]),
      ]);
      final builder = SchemaBuilder(library);
      final models = builder.loadModels('TestOwner');
      builder.linkModels(models);
      expect(models.length, 1);
      expect(models[0].fields.length, 2);
      final Foo = models[0];
      expect(Foo.fields[0].linkedModel, isNull);
      expect(Foo.fields[1].linkedField.type, 'Link<Foo>');
      expect(Foo.fields[1].linkedField.name, 'parent');
      expect(Foo.fields[1].linkedField.isVirtual, isTrue);
    });
  });

  group('test expandedModels', () {
    test('Foo.HasMany<Bat>|Bar.HasMany<Bat> -> Bat<Foo>.parent|Bat<Bar>.bar, generic', () {
      final library = libraryReader([
        ClassDef('@model Foo', fields: [FieldDef('HasMany<Bat> bats')]),
        ClassDef('@model Bar', fields: [FieldDef('HasMany<Bat> bats')]),
        ClassDef('@model Bat<P>', fields: [FieldDef('Link<Foo> foo'), FieldDef('Link<Bar> bar')]),
      ]);
      final builder = SchemaBuilder(library);
      final models = builder.loadModels('TestOwner');
      builder.linkModels(models);
      builder.expandModels(models);
      final Foo = models[0], Bar = models[1], Bat = models[2];
      expect(models.length, 3);
      expect(Foo.isGeneric, isFalse);
      expect(Bar.isGeneric, isFalse);
      expect(Bat.isGeneric, isTrue);
      expect(Bat.expanded.length, 2);
      expect(Bat.expanded[0].isGeneric, isFalse);
      expect(Bat.expanded[0].isConcrete, isTrue);
      expect(Bat.expanded[0].type, 'Bat<Foo>');
      expect(Bat.expanded[1].isGeneric, isFalse);
      expect(Bat.expanded[1].isConcrete, isTrue);
      expect(Bat.expanded[1].type, 'Bat<Bar>');
    });

    test('Message<P>|Marker<P>', () {
      final schema = schemaDef([
        classDef('@owner @scaffold Message<P>', ['Link<P> parent', 'HasMany<Marker> markers', 'HasMany<Message> messages',]),
        classDef('@model @scaffold Marker<P>', ['Link<P> parent',]),
      ]);
      expect(schema.models.length, 2);
      final Message = schema.models[0], Marker = schema.models[1];
      expect(Message.isGeneric, isTrue);
      expect(Message.fields[1].model.type, 'Message<P>');
      expect(Message.fields[1].type, 'HasMany<Marker<Message>>');
      expect(Message.fields[1].name, 'markers');
      expect(Message.expanded.length, 1);
      expect(Message.expanded[0], isNot(Message));
      expect(Message.expanded[0].isGeneric, isFalse);
      expect(Message.expanded[0].isConcrete, isTrue);
      expect(Message.expanded[0].fields[1].model.type, 'Message<Message>');
      expect(Message.expanded[0].fields[1].type, 'HasMany<Marker<Message>>');
      expect(Message.expanded[0].fields[1].name, 'markers');
      expect(Message.expanded[0].fields[1].linkedModel.type, 'Marker<Message>');
      expect(Message.expanded[0].fields[1].linkedField.type, 'Link<Message<Marker>>');
      expect(Message.expanded[0].fields[1].linkedField.name, 'parent');
      expect(Marker.isGeneric, isTrue);
    });
  });
}
