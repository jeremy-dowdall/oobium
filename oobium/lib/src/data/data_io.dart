import 'dart:io';

import 'data_base.dart' as base;

class Data extends base.Data {

  Data(String path, {int version = 1}) : super(path, version:  version);

  Directory dir;

  @override
  Future<Data> create() async {
    dir = Directory(path);
    if(!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return this;
  }

  @override
  dynamic connect(base.Connection connection) {
    super.connect(connection);
    return dir.path;
  }

  @override
  Future<void> close({bool cancel = false}) async {
    await super.close(cancel: cancel ?? false);
    dir = null;
  }

  @override
  Future<void> destroy() async {
    await close(cancel: true);
    final dir = Directory(path);
    if(await dir.exists()) {
      return dir.delete(recursive: true);
    }
  }
}