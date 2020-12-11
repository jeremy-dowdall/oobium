import 'dart:io';

import 'package:oobium_common/oobium_common.dart';

void main() async {

  final file = File('<TODO>');
  final fileName = file.path.substring(file.parent.path.length);
  final fileSize = (await file.stat()).size;

  final socket = await WebSocket().connect(address: '127.0.0.1', port: 4040, path: '/ws');

  final result = await socket.get('/files/$fileName/stat');
  if(result.isSuccess) {
    final data = result.data as Map<String, dynamic>;
    final size = data['size'] as int;
    final lastModified = data['lastModified'] as int;
    if(size < fileSize) {
      // final uploadResult = await socket.put('/files/$fileName',
      //   {'file': fileName, 'size': fileSize, 'start': size, 'resume': true},
      //
      // );
    }
  } else {
    print('error: ${result.code}');
  }

  await socket.close();
}
