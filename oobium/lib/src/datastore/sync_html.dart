import 'dart:convert';
import 'dart:indexed_db';

import 'package:oobium/src/datastore/data.dart';
import 'package:oobium/src/datastore.dart' show DataModel, DataRecord;

import 'sync_base.dart' as base;
export 'sync_base.dart' show DataEvent;

class Sync extends base.Sync {

  Sync(Data ds, Function(base.DataEvent event) onDataEvent, Iterable<DataModel> Function() onGetSyncRecords) : super(ds, onDataEvent, onGetSyncRecords);

  late Database idb;

  @override
  Future<Sync> open() async {
    idb = ds.connect(this);
    final tx = idb.transaction('sync', 'readonly').objectStore('sync');
    final json = await tx.getObject('sync');
    if(json is String && json.isNotEmpty) {
      final data = jsonDecode(json);
      if(data is List && data.isNotEmpty) {
        id = data.first.toString();
        for(var id in data.skip(1)) {
          replicants.add(await Replicant(ds, id.toString()).open());
        }
      }
    }
    return this;
  }

  @override
  Future<void> save() async {
    final data = jsonEncode([id, ...replicants.map((r) => r.id)]);
    final tx = idb.transaction('sync', 'readwrite').objectStore('sync');
    await tx.put(data, 'sync');
  }
}

class Replicant extends base.Replicant {

  Replicant(Data ds, String id) : super(ds, id);

  late Database idb;

  @override
  Replicant open() {
    idb = ds.connect(this);
    return this;
  }

  @override
  Stream<DataRecord> getSyncRecords(Iterable<DataModel> models) async* {
    final tx = idb.transaction('sync', 'readonly').objectStore('sync');
    final lastSync = (await tx.getObject('$id-lastSync')) as int;
    for(var model in models.where((model) => model.updatedAt.millisecondsSinceEpoch > lastSync)) {
      yield(DataRecord.fromModel(model));
    }
    final records = await tx.openCursor(autoAdvance: true).where((c) => (c.key as String).startsWith('$id:')).map((c) {
      return DataRecord.fromLine(c.value as String);
    });
    await for(var record in records) {
      yield(record);
    }
  }

  @override
  Future<void> save() async {
    final lastSync = DateTime.now().millisecondsSinceEpoch;
    return idb.transaction('sync', 'readwrite').objectStore('sync').put(lastSync, '$id-lastSync');
  }

  @override
  Future<void> saveRecords(Iterable<DataRecord> records) async {
    final tx = idb.transaction('sync', 'readwrite').objectStore('sync');
    for(var record in records) {
      tx.put(record.toString(), '$id:${record.modelId}');
    }
    await tx.transaction?.completed;
  }
}
