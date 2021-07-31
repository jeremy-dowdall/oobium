import 'dart:async';

import 'package:oobium_datastore/src/datastore.dart';
import 'package:oobium_datastore/src/datastore/data.dart';
import 'package:oobium_datastore/src/datastore/repo.dart';

class DataWorker {
  final String path;
  late Data _data;
  late Repo _repo;
  // Sync sync;
  DataWorker(this.path);

  int _version = 0;
  int get version => _version;

  bool _open = false;
  bool get isOpen => _open;
  bool get isNotOpen => !isOpen;

  Future<DataWorker> open({int version=1, Stream<DataRecord> Function(UpgradeEvent event)? onUpgrade}) async {
    assert(isNotOpen);
    _open = true;
    _version = version;
    _data = await Data(path).open(version: version, onUpgrade: (event) async {
      if(onUpgrade != null) {
        final oldRepo = (event.oldData != null) ? (await Repo(event.oldData!).open()) : null;
        final stream = onUpgrade(UpgradeEvent(event.oldVersion, event.newVersion, oldRepo?.get() ?? Stream<DataRecord>.empty()));
        final newRepo = await Repo(event.newData).open();
        newRepo.put(stream);
        await newRepo.flush();
        await newRepo.close();
        await oldRepo?.close();
      }
      return true;
    });
    _repo = await Repo(_data).open();
    return this;
  }

  Future<void> flush() async {
    assert(isOpen);
    await _repo.flush();
  }

  Future<void> close() async {
    assert(isOpen);
    await _repo.flush();
    await _repo.close();
    await _data.close();
  }

  Future<void> destroy() async {
    assert(isOpen);
    await _repo.close();
    await _data.destroy();
  }

  Stream<DataRecord> getData() {
    assert(isOpen);
    return _repo.get();
  }

  Future<void> putData({Iterable<DataRecord>? update, Iterable<DataRecord>? reset}) async {
    assert(isOpen);
    if(reset != null) {
      await _repo.reset(reset);
    }
    if(update != null) {
      await _repo.putAll(update);
    // await _sync.putAll(records);
    }
  }
}