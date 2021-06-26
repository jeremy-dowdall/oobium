import 'dart:async';

import 'package:oobium_websocket/oobium_websocket.dart';
import 'package:tools_common/processes.dart';

Stream<List<int>> statusHandler(WsRequest req) async* {
  yield* run('dart', ['--version']);
  yield* run('flutter', ['--version']);
}
