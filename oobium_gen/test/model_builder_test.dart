import 'package:oobium_gen/src/util/model.dart';
import 'package:oobium_gen/src/util/model_builder.dart';
import 'package:oobium_gen/src/util/model_field.dart';
import 'package:test/test.dart';

void main() {
  group('test build models', () {
    test('empty model', () {
      final model = Model(owner: 'TestOwner', type: 'Foo');
      final source = ModelBuilder(model).build();
      expect(source, contains('class Foo extends Model<Foo, TestOwner>'));
    });

    test('Foo.String', () {
      final model = Model(owner: 'TestOwner', type: 'Foo', fields: [
        ModelField(type: 'String', name: 'name')
      ]);
      final source = ModelBuilder(model).build();
      expect(source, contains('final String name;'));
    });

    test('Foo<P>, generic model', () {
      final model = Model(owner: 'TestOwner', type: 'Foo<P>');
      final source = ModelBuilder(model).build();
      expect(source, contains('class Foo<P> extends Model<Foo<P>, TestOwner>'));
      expect(source, contains('..[\'_type\'] = Json.from(P)'));
    });
  });
}