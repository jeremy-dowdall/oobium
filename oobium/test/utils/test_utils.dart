import 'package:oobium/src/datastore.dart';
import 'package:oobium/src/datastore/data.dart';
import 'package:oobium/src/datastore/repo.dart';

import 'test_models.dart';

final datastores = <DataStore>[];
final data = <Data>[];
final repo = <Repo>[];

DataStore createDatastore(String testFile, [DataStore? clone]) {
  final path = clone?.path ?? 'test-data/$testFile/test-ds-${datastores.length}';
  final ds = DataStore(path, [
    (data) => TestType1.fromJson(data),
    (data) => TestType2.fromJson(data),
  ]);
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
