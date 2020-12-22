import 'dart:html';

class WsFile {
  final String path;
  WsFile(this.path);

  Stream<List<int>> get stream => throw UnsupportedError('platform not supported');
}