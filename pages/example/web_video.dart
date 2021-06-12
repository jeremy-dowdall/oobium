import 'dart:io';

import 'package:oobium_server/oobium_server.dart';
import 'package:oobium_pages/oobium_pages.dart';

void main() {
  final server = Server();

  server.get('/video', [(req, res) => res.sendPage(
      Page(content: [ video(autoplay: true, controls: true, src: '/video/src') ]))
  ]);

  server.get('/video/src', [(req, res) => res.sendFile(
      File('examples/assets/video.mp4')
  )]);

  server.start();
}