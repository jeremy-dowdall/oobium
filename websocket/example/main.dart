import 'package:oobium_server/oobium_server.dart';
import 'package:oobium_websocket/oobium_websocket.dart';

void main() async {
  final server = Server();

  server.get('/ws', [websocket((socket) {
    socket.on.get('/echo/<test>', (req) {
      return 'received: ${req['test']}';
    });
  })]);

  await server.start();

  final socket = await WebSocket().connect(path: '/ws');

  final result = await socket.get('/echo/hello');
  if(result.isSuccess) {
    print('response: ${result.data}');
  } else {
    print('error: ${result.code}');
  }

  await socket.close();
  await server.close();
}
