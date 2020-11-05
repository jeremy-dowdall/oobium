import 'dart:io';

import 'package:oobium_server/oobium_server.dart';

void main() async {
  // final file = File('//Users/jeremydowdall/CocoaV/2pc-assortments-fireplace.jpg');
  final file = File('/Users/jeremydowdall/Downloads/MVI_0096.MP4');
  // final file = File('examples/data.txt');
  final url = 'ws://${InternetAddress.loopbackIPv4.address}:4040/ws';
  final socket = await ClientWebSocket.connect(url);
  socket.start();
  final result = await socket.addTask(FileSendTask(
    file: file,
    onReplace: () => true,
    onResume: () => Resolution.resume,
    onStatus: (status) => print('progress: ${status.percent}%')
  ));
  print('result: $result');
  socket.close();
}
