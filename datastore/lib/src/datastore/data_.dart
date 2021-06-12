import 'dart:async';

import 'package:oobium_datastore/src/datastore/data.dart';

class DataPlatform {

  DataPlatform(Data data);

  Future<void> open({int? version, FutureOr<bool> Function(DataUpgradeEvent event)? onUpgrade}) {
    throw UnsupportedError('platform not supported');
  }

  dynamic connect() {
    throw UnsupportedError('platform not supported');
  }

  Future<void> close() {
    throw UnsupportedError('platform not supported');
  }

  Future<void> destroy() {
    throw UnsupportedError('platform not supported');
  }
}
