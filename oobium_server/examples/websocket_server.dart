import 'dart:io';

import 'package:oobium_server/oobium_server.dart';

void main() {
  final server = Server();

  server.get('/ws', [websocket((socket) {
    socket.on.get('/files/<fileName>/stat', (req, res) async {
      final fileName = req.params['fileName'];
      final file = File('$fileName');
      if(await file.exists()) {
        final stat = await file.stat();
        res.send(data: {
          'fileName': fileName,
          'size': stat.size,
          'lastModified': stat.modified.millisecondsSinceEpoch
        });
      } else {
        res.send(code: 404);
      }
    });
    socket.on.put('/files/<fileName>', (req, res) {
      // TODO
    });
  })]);

  // server.get('/ws', [(req, res) async {
  //   final ws = await req.upgrade();
  //   ws.addHandler(FileQueryHandler('examples/db'));
  //   ws.addHandler(FileSendHandler('examples/db'));
  //   ws.start();
  // }]);

  server.start();
}
