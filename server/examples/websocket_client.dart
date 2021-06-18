import 'package:oobium_websocket/oobium_websocket.dart';

void main() async {

  final socket = await WebSocket().connect(path: '/ws');

  final result = await socket.get('/echo/hello');
  if(result.isSuccess) {
    print('response: ${result.data}');
  } else {
    print('error: ${result.code}');
  }

  await socket.close();
}
