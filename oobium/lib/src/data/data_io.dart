import 'dart:async';
import 'dart:io';

import 'data_base.dart' as base;

class Data extends base.Data {

  Data(String path) : super(path);

  Directory dir;

  @override
  Future<Data> open({int version, FutureOr<bool> Function(base.DataUpgradeEvent event) onUpgrade}) async {
    final vf = File('$path/version');
    final oldVersion = (await vf.exists()) ? int.parse(await vf.readAsString()) : 0;
    final newVersion = version ?? ((oldVersion == 0) ? 1 : oldVersion);
    dir = Directory('$path/$newVersion');
    if(!await dir.exists()) {
      await dir.create(recursive: true);
    }
    if(newVersion != oldVersion) {
      final oldData = (oldVersion > 0) ? (await Data(path).open(version: oldVersion)) : null;
      final upgraded = (await onUpgrade?.call(base.DataUpgradeEvent(oldVersion, oldData, newVersion, this))) ?? true;
      if(upgraded) {
        await vf.writeAsString(newVersion.toString());
        await oldData?.destroy();
      }
    }
    return this;
  }

  @override
  dynamic connect(base.Connection connection) {
    super.connect(connection);
    return dir.path;
  }

  @override
  Future<void> close() async {
    await super.close();
    dir = null;
  }

  @override
  Future<void> destroy() async {
    await close();
    final dir = Directory(path);
    if(await dir.exists()) {
      return dir.delete(recursive: true);
    }
  }
}