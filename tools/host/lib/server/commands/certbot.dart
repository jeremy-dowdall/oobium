import 'dart:io';

import 'package:oobium_websocket/oobium_websocket.dart';

final certbotPath = 'todo';

certbotHandler(WsRequest req) async {
  final file = File('$certbotPath/${req['file']}');
  if(await file.exists()) {
    return await file.readAsString();
  }
  return 404;
}