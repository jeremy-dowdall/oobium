import 'package:oobium_server/oobium_server.dart';
import 'package:oobium_websocket/oobium_websocket.dart';

void main() async {
  final server = Server();

  server.get('/ws', [websocket((socket) {
    socket.on.get('/echo/<msg>', (req) async {
      await req.socket.get('/ping/1');
      return req['msg'];
    });
    socket.on.get('/pong/<count>', (req) {
      print(req.path);
      final count = int.parse(req['count']);
      if(count < 10) {
        return req.socket.get('/ping/${count + 1}');
      } else {
        return 'pong is done';
      }
    });
  })]);

  await server.start();

  final socket = await WebSocket().connect(path: '/ws');
  socket.on.get('/ping/<count>', (req) {
    print(req.path);
    final count = int.parse(req['count']);
    if(count < 10) {
      return req.socket.get('/pong/${count + 1}');
    } else {
      return 'ping is done';
    }
  });

  final result = await socket.get('/echo/hello');
  if(result.isSuccess) {
    print('response: ${result.data}');
  } else {
    print('error: ${result.code}');
  }

  await socket.close();
  await server.close();
}
