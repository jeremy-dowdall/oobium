import 'dart:io';

import 'package:oobium_server/oobium_server.dart';

void main() {
  final server = Server();

  server.get('/video', [(req, res) => res.sendPage(
      Page(content: [ video(autoplay: true, controls: true, src: '/video/src') ]))
  ]);

  server.get('/video/src', [(req, res) => res.sendFile(
      File('/Users/jeremydowdall/Downloads/MVI_0096.MP4')
  )]);

  server.start();
}