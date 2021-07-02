import 'dart:io';

import 'package:oobium_websocket/oobium_websocket.dart';
import 'package:tools_common/models.dart';

import '../_base.dart';

class StatusCommand extends ConnectedCommand {
  @override final name = 'status';
  @override final description = 'display the status for a project on an oobium host';

  @override
  Future<void> runWithConnection(Project project, WebSocket ws) {
    return ws.getStream('/status').listen((e) => stdout.add(e)).asFuture();
  }
}
