import 'package:oobium_websocket/oobium_websocket.dart';
import 'package:tools_common/processes.dart';

Stream<List<int>> deployHandler(WsRequest req) async* {
  final result = await req.socket.put('/exec', 'please enter a command');
  if(result.isSuccess) {
    final cmd = '${result.data}'.split(' ');
    yield* run(cmd[0], cmd.skip(1).toList());
  }
}
