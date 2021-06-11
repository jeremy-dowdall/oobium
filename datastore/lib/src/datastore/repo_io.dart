import 'dart:io';

import 'package:oobium_datastore/src/datastore/data.dart';
import 'package:oobium_datastore/src/datastore.dart';
import 'package:oobium_datastore/src/datastore/executor.dart';

import 'repo_base.dart' as base;

class Repo extends base.Repo {

  Repo(Data data) : super(data);

  late File file;

  @override
  Future<Repo> open() async {
    file = File('${data.connect(this)}/repo');
    await file.create();
    return this;
  }

  @override
  Stream<DataRecord> get([int? timestamp]) async* {
    // TODO timestamp unused
    for(var line in await file.readAsLines()) {
      yield(DataRecord.fromLine(line));
    }
  }

  @override
  Future<void> put(Stream<DataRecord> records) {
    return executor.add((e) async {
      final sink = file.openWrite(mode: FileMode.append);
      await for(var record in records) {
        if(e.isCanceled) break;
        sink.writeln(record);
      }
      if(e.isNotCanceled) await sink.flush();
      await sink.close();
    });
  }

  @override
  Future<void> putAll(Iterable<DataRecord> records) {
    return executor.add((e) async {
      final sink = file.openWrite(mode: FileMode.append);
      for(var record in records) {
        if(e.isCanceled) break;
        sink.writeln(record);
      }
      if(e.isNotCanceled) await sink.flush();
      await sink.close();
    });
  }

  @override
  Future<void> reset(Iterable<DataRecord> records) async {
    executor.cancel();
    executor = Executor();
    return executor.add((e) async {
      await Future.delayed(Duration());
      if(e.isCanceled) {
        return;
      }
      print('resetting');
      final start = DateTime.now();
      final reset = File('${file.path}.reset');
      final sink = reset.openWrite(mode: FileMode.write);
      for(final record in records) {
        if(e.isCanceled) {
          break;
        }
        sink.writeln(record);
      }
      if(e.isNotCanceled) await sink.flush();
      await sink.close();
      if(e.isNotCanceled) await reset.rename(file.path);
      print('reset(${e.isNotCanceled}) in ${DateTime.now().millisecondsSinceEpoch - start.millisecondsSinceEpoch} ms');
    });
  }
}
