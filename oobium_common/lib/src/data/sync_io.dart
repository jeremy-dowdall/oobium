import 'dart:io' hide WebSocket;

import 'package:oobium_common/src/data/repo.dart';
import 'package:oobium_common/src/database.dart';
import 'package:oobium_common/src/websocket.dart';

import 'sync_base.dart' as base;

class Sync extends base.Sync {

  Sync(String db, Repo repo) : super(db, repo);

  String get path => '$db/sync';
  File get file => File(path);

  @override
  Future<Sync> open() async {
    await file.create();
    final lines = await file.readAsLines();
    if(lines.isNotEmpty) {
      id = lines.first;
      for(var id in lines.skip(1)) {
        replicants.add(await Replicant(db, id).open());
      }
    }
    return this;
  }

  @override
  Future<void> close({bool cancel = false}) async {
    for(var replicant in replicants) {
      await replicant.close(cancel: cancel ?? false);
    }
    id = null;
    replicants.clear();
    return Future.value();
  }

  Future<void> save() async {
    final sink = file.openWrite();
    sink.writeln(id);
    for(var replicant in replicants) {
      sink.writeln(replicant.id);
    }
    await sink.flush();
    await sink.close();
  }
}

class Binder extends base.Binder {

  Binder(Sync sync, WebSocket socket) : super(sync, socket);

}

class Replicant extends base.Replicant {

  Replicant(String db, String id) : super(db, id);

  String get path => '$db/sync.$id';
  File get file => File(path);

  Future<Replicant> open() => startTracking().then((_) => Future.value(this));
  Future<void> destroy() => Future.value();

  Stream<DataRecord> getSyncRecords(Repo repo) async* {
    final lines = await file.readAsLines();
    final lastSync = int.parse(lines[0]);
    await for(var record in repo.get(lastSync)) {
      yield(record);
    }
    for(var record in lines.skip(1).map((l) => DataRecord.fromLine(l))) {
      yield(record);
    }
  }

  Future<void> save() {
    final lastSync = DateTime.now().millisecondsSinceEpoch.toString();
    return file.writeAsString(lastSync);
  }

  Future<void> saveRecords(Iterable<DataRecord> records) async {
    final sink = file.openWrite(mode: FileMode.append);
    for(var record in records) {
      sink.writeln(record);
    }
    await sink.flush();
    await sink.close();
  }
}
