import 'dart:io';

class WsFile {
  final String path;
  WsFile(this.path);

  Stream<List<int>> get stream => File(path).openRead();
}