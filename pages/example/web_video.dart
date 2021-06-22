import 'dart:io';

import 'package:oobium_server/oobium_server.dart';
import 'package:oobium_pages/oobium_pages.dart';

void main() {
  final server = Server();

  server.get('/video', [(req) => Page(
      content: [ video(autoplay: true, controls: true, src: '/video/src') ]
  )]);

  server.get('/video/src', [(req) => File('examples/path/to/large.mp4')]);

  server.start();
}