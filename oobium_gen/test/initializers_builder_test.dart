import 'package:oobium_gen/src/util/initializers_builder.dart';
import 'package:oobium_gen/src/util/model.dart';
import 'package:oobium_gen/src/util/schema_builder.dart';
import 'package:oobium_gen/src/util/schema_library.dart';
import 'package:test/test.dart';

void main() {
  group('test build', () {
    test('Foo', () {
      final models = [Model(type: 'Foo')];
      final source = (InitializersBuilder(imports: [], models: models)).build();
      expect(source, contains('addBuilder<Foo>((context, data) => Foo.fromJson(context, data));'));
      expect(source, contains('register<Foo>(persistor);'));
    });

    test('Foo<P>, with no expanded types', () {
      final models = [Model(type: 'Foo<P>')];
      final source = (InitializersBuilder(imports: [], models: models)).build();
      expect(source, contains('addBuilder<Foo>((context, data) => Foo.fromJson(context, data));'));
    });

    test('Foo<P>, with expanded types', () {
      final schema = SchemaBuilder(SchemaLibrary.parse([
        'Foo(owner)', '  bars HasMany<Bar>',
        'Bar<P>', '  foo Link<P>',
      ])).build();
      final lines = (InitializersBuilder(imports: [], models: schema.models)).build().split('\n');
      var index = lines.indexWhere((line) => line.trim() == 'void addSchemaBuilders() {');
      expect(lines[++index].trim(), 'addBuilder<Foo>((context, data) => Foo.fromJson(context, data));');
      expect(lines[++index].trim(), 'addBuilder<Bar>((context, data) {');
      expect(lines[++index].trim(), 'final type = Json.field(data, \'_type\');');
      expect(lines[++index].trim(), 'if(type == \'Foo\') return Bar<Foo>.fromJson(context, data);');
      expect(lines[++index].trim(), 'return Bar.fromJson(context, data);');
      expect(lines[++index].trim(), '});');
      expect(lines[++index].trim(), 'addBuilder<Bar<Foo>>((context, data) => Bar<Foo>.fromJson(context, data));');
    });
  });
}