import 'dart:io';

import 'data_base.dart' as base;

class Data extends base.Data {

  Data(String path) : super(path);

  Directory get dir => Directory(path);

  @override
  Future<void> create() => dir.exists().then((exists) => exists ? Future.value() : dir.create(recursive: true));

  @override
  Future<void> destroy() => dir.exists().then((exists) => exists ? dir.delete(recursive: true) : Future.value());

}