import 'package:oobium_common/src/data/database.dart';
import 'package:oobium_common/src/data/models.dart';
import 'package:oobium_common/src/json.dart';
import 'package:test/test.dart';

void main() async {

  test('test main context', () async {
    final db = Database('test.db');
    final context = ModelContext(db);
    final type1 = TestType1(name: 'test01', type2: TestType2());
    context.put(type1);

    final model = context.get<TestType1>(type1.id);
  });

  test('test contacts', () async {
    final db = Database('test.db');
    final context = ModelContext(db);

    // final contact = context.getAll<Contact>();
  });
}

class TestType1 extends JsonModel {
  final String name;
  final TestType2 type2;
  TestType1({String id, this.name, this.type2}) : super(id);
  TestType1.fromJson(data) : name = Json.field(data, 'name'), type2 = Json.field(data, 'type2', (v) => TestType2.fromJson(v)), super.fromJson(data);
  @override Map<String, dynamic> toJson() => super.toJson()..['name'] = name;
}

class TestType2 extends JsonModel {
  final String name;
  final TestType1 type2;
  TestType2({String id, this.name, this.type2}) : super(id);
  TestType2.fromJson(data) : name = Json.field(data, 'name'), type2 = Json.field(data, 'type2', (v) => TestType1.fromJson(v)), super.fromJson(data);
  @override Map<String, dynamic> toJson() => super.toJson()..['name'] = name;
}
