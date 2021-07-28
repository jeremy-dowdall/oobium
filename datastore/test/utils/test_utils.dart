import 'package:objectid/objectid.dart';
import 'package:oobium_datastore/src/adapters.dart';
import 'package:oobium_datastore/src/datastore.dart';
import 'package:oobium_datastore/src/datastore/data.dart';
import 'package:oobium_datastore/src/datastore/models.dart';
import 'package:oobium_datastore/src/datastore/repo.dart';

final datastores = <DataStore>[];
final data = <Data>[];
final repo = <Repo>[];

class TestType1 extends DataModel {
  ObjectId get id => this['_modelId'];
  String? get name => this['name'];
  TestType1({String? name}) : super({'name': name});
  TestType1._(map) : super(map);
  TestType1.copyNew(TestType1 original, {String? name}) : super.copyNew(original, {'name': name});
  TestType1.copyWith(TestType1 original, {String? name}) : super.copyWith(original, {'name': name});
  TestType1.deleted(TestType1 original) : super.deleted(original);
  TestType1 copyNew({String? name}) => TestType1.copyNew(this, name: name);
  TestType1 copyWith({String? name}) => TestType1.copyWith(this, name: name);
  TestType1 deleted() => TestType1.deleted(this);
}

class TestType2 extends DataModel {
  ObjectId get id => this['_modelId'];
  String? get name => this['name'];
  TestType1? get type1 => this['type1'];
  TestType2({String? name, TestType1? type1}) : super({'name': name});
  TestType2._(map) : super(map);
  TestType2.copyNew(TestType2 original, {String? name, TestType1? type1}) : super.copyNew(original, {'name': name, 'type1': type1});
  TestType2.copyWith(TestType2 original, {String? name, TestType1? type1}) : super.copyWith(original, {'name': name, 'type1': type1});
  TestType2.deleted(TestType2 original) : super.deleted(original);
  TestType2 copyNew({String? name, TestType1? type1}) => TestType2.copyNew(this, name: name, type1: type1);
  TestType2 copyWith({String? name, TestType1? type1}) => TestType2.copyWith(this, name: name, type1: type1);
  TestType2 deleted() => TestType2.deleted(this);
}

DataStore createDatastore(String testFile, {
  DataStore? clone,
  String? isolate,
  List<Function(Map data)> builders = const[],
  List<DataIndex> indexes = const[],
  CompactionStrategy compactionStrategy = const DefaultCompactionStrategy()
}) {
  final path = clone?.path ?? 'test-data/$testFile/test-ds-${datastores.length}';
  final ds = DataStore(path,
    isolate: isolate,
    adapters: Adapters([
      Adapter<TestType1>(
        decode: (map) => TestType1._(map),
        encode: (k,v) => v,
        fields: ['name']
      ),
      Adapter<TestType2>(
        decode: (map) => TestType2._(map),
        encode: (k,v) => v,
        fields: ['name','type1']
      )
    ]),
    indexes: indexes,
    compactionStrategy: compactionStrategy
  );
  datastores.add(ds);
  return ds;
}

Data createData(String testFile, [Data? clone]) {
  final path = clone?.path ?? 'test-data/$testFile/test-d-${data.length}';
  final d = Data(path);
  data.add(d);
  return d;
}

Repo createRepo(Data data) {
  final r = Repo(data);
  repo.add(r);
  return r;
}

Future<void> destroy(String testFile) => Future.wait([
  Future.forEach<DataStore>(datastores.where((ds) => ds.path.contains('/$testFile/')), (ds) { if(datastores.remove(ds)) ds.destroy(); }),
  Future.forEach<Data>(data.where((ds) => ds.path.contains('/$testFile/')), (d) { if(data.remove(d)) d.destroy(); }),
]);

Future<void> destroyData(String testFile) => Data('test-data/$testFile').destroy();
