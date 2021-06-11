import 'dart:indexed_db';

import 'package:oobium_datastore/src/datastore/data.dart';
import 'package:oobium_datastore/src/datastore.dart' show DataRecord;

import 'repo_base.dart' as base;

class Repo extends base.Repo {

  Repo(Data data) : super(data);

  late Database idb;

  @override
  Future<Repo> open() {
    idb = data.connect(this);
    return Future.value(this);
  }

  @override
  Stream<DataRecord> get([int? timestamp]) {
    // TODO timestamp unused
    return idb.transaction('repo', 'readonly').objectStore('repo').openCursor(autoAdvance: true).map((event) {
      return DataRecord.fromLine(event.value);
    });
  }

  @override
  Future<void> put(Stream<DataRecord> records) async {
    final futures = <Future>[];
    await for(var record in records) {
      if(record.isDelete) {
        futures.add(executor.add((_) => idb.transaction('repo', 'readwrite').objectStore('repo').delete(record.modelId)));
      } else {
        futures.add(executor.add((_) => idb.transaction('repo', 'readwrite').objectStore('repo').put(record.toString(), record.modelId)));
      }
    }
    await Future.wait(futures);
  }

  @override
  Future<void> putAll(Iterable<DataRecord> records) {
    return executor.add((_) async {
      final tx = idb.transaction('repo', 'readwrite').objectStore('repo');
      for(var record in records) {
        if(record.isDelete) {
          await tx.delete(record.modelId);
        } else {
          await tx.put(record.toString(), record.modelId);
        }
      }
    });
  }

  @override
  Future<void> reset(Iterable<DataRecord> records) => Future.value();
}
