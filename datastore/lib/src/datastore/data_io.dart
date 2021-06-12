import 'dart:async';
import 'dart:io';

import 'package:oobium_datastore/src/datastore/data.dart';
import 'package:oobium_datastore/src/datastore/data_.dart' as base;

class DataPlatform implements base.DataPlatform {

  final Data data;
  DataPlatform(this.data);

  Directory? dir;

  Future<void> open({int? version, FutureOr<bool> Function(DataUpgradeEvent event)? onUpgrade}) async {
    final vf = File('${data.path}/version');
    final oldVersion = (await vf.exists()) ? int.parse(await vf.readAsString()) : 0;
    final newVersion = version ?? ((oldVersion == 0) ? 1 : oldVersion);
    dir = Directory('${data.path}/$newVersion');
    if(!await dir!.exists()) {
      await dir!.create(recursive: true);
    }
    if(newVersion != oldVersion) {
      final oldData = (oldVersion > 0) ? (await Data(data.path).open(version: oldVersion)) : null;
      final upgraded = (await onUpgrade?.call(DataUpgradeEvent(oldVersion, oldData, newVersion, data))) ?? true;
      if(upgraded) {
        await vf.writeAsString('$newVersion');
        await oldData?.destroy();
      }
    }
  }

  dynamic connect() {
    return dir!.path;
  }

  Future<void> close() async {
    dir = null;
  }

  Future<void> destroy() async {
    final dir = Directory(data.path);
    if(await dir.exists()) {
      await dir.delete(recursive: true).catchError((_) {
        print('destroy failed');
      });
    }
  }
}
