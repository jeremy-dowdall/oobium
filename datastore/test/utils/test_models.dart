import 'package:objectid/objectid.dart';
import 'package:oobium_datastore/src/datastore/models.dart';

class TestType1 extends DataModel {
  ObjectId get id => this['_modelId'];
  String? get name => this['name'];
  TestType1({String? name}) : super({'name': name});
  TestType1.copyNew(TestType1 original, {String? name}) : super.copyNew(original, {'name': name});
  TestType1.copyWith(TestType1 original, {String? name}) : super.copyWith(original, {'name': name});
  TestType1.fromJson(data) : super(data);
  TestType1 copyNew({String? name}) => TestType1.copyNew(this, name: name);
  TestType1 copyWith({String? name}) => TestType1.copyWith(this, name: name);
}

class TestType2 extends DataModel {
  ObjectId get id => this['_modelId'];
  String? get name => this['name'];
  TestType1? get type1 => this['type1'];
  TestType2({String? name, TestType1? type1}) : super({'name': name});
  TestType2.copyNew(TestType2 original, {String? name, TestType1? type1}) : super.copyNew(original, {'name': name, 'type1': type1});
  TestType2.copyWith(TestType2 original, {String? name, TestType1? type1}) : super.copyWith(original, {'name': name, 'type1': type1});
  TestType2.fromJson(data) : super(data);
  TestType2 copyNew({String? name, TestType1? type1}) => TestType2.copyNew(this, name: name, type1: type1);
  TestType2 copyWith({String? name, TestType1? type1}) => TestType2.copyWith(this, name: name, type1: type1);
}
