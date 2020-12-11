import 'dart:io' hide WebSocket;

import 'package:oobium_common/src/data/data.dart';
import 'package:oobium_common/src/data/models.dart';
import 'package:oobium_common/src/data/repo.dart';
import 'package:oobium_common/src/database.dart';

import 'sync_base.dart' as base;

class Sync extends base.Sync {

  Sync(Data db, Repo repo, [Models models]) : super(db, repo, models);

  File file;

  @override
  Future<Sync> open() async {
    file = File('${db.connect(this)}/sync');
    if(await file.exists()) {
      final lines = await file.readAsLines();
      if(lines.isNotEmpty) {
        id = lines.first;
        for(var id in lines.skip(1)) {
          replicants.add(await Replicant(db, id).open());
        }
      }
    } else {
      await file.create();
    }
    return this;
  }

  Future<void> save() async {
    assert(id != null);
    final sink = file.openWrite();
    sink.writeln(id);
    for(var replicant in replicants) {
      sink.writeln(replicant.id);
    }
    await sink.flush();
    await sink.close();
  }
}

class Replicant extends base.Replicant {

  Replicant(Data db, String id) : super(db, id);

  File file;

  @override
  Future<Replicant> open() {
    file = File('${db.connect(this)}/sync.$id');
    return startTracking().then((_) => Future.value(this));
  }

  @override
  Stream<DataRecord> getSyncRecords(Models models) async* {
    final lines = await file.readAsLines();
    final lastSync = int.parse(lines[0]);
    for(var model in models.getAll().where((model) => model.timestamp > lastSync)) {
      yield(DataRecord.fromModel(model));
    }
    for(var record in lines.skip(1).map((l) => DataRecord.fromLine(l))) {
      yield(record);
    }
  }

  @override
  Future<void> save() {
    final lastSync = DateTime.now().millisecondsSinceEpoch.toString();
    return file.writeAsString(lastSync);
  }

  @override
  Future<void> saveRecords(Iterable<DataRecord> records) async {
    final sink = file.openWrite(mode: FileMode.append);
    for(var record in records) {
      sink.writeln(record);
    }
    await sink.flush();
    await sink.close();
  }
}
