import 'dart:async';
import 'dart:io' if (dart.library.html) 'ws_html.dart';

import 'package:oobium_server/src/websocket/websocket.dart';

class ClientWebSocket extends BaseWebSocket {
  ClientWebSocket(WebSocket ws) : super(ws);
  static Future<ClientWebSocket> connect(String url) async => ClientWebSocket(await WebSocket.connect(url));
}

enum Resolution { replace, resume, cancel }
class Status {
  final int position;
  final int total;
  final String message;
  Status({this.position, this.total, this.message});
  int get percent => 100 * position ~/ total;
}

class FileSendTask extends Task {

  final File file;
  final FutureOr<Resolution> Function() onResume;
  final FutureOr<bool> Function() onReplace;
  final void Function(Status status) onStatus;
  FileSendTask({this.file, this.onResume, this.onReplace, this.onStatus});

  @override
  void registerMessageBuilders() {
    register<Ready>(Ready.builder);
    register<FileQueryResults>(FileQueryResults.builder);
  }

  String _fileName;
  int _fileSize;
  int _position;
  bool _resume;
  RandomAccessFile reader;
  final _buffer = List<int>.filled(1024*1024, 0);

  @override
  void onStart() async {
    _fileName = file.path.substring(file.parent.path.length);
    _fileSize = (await file.stat()).size;
    addMessage(FileQuery(_fileName));
  }

  @override
  Future<WebSocketMessage> onFinish([WebSocketMessage result]) async {
    await reader.close();
    return super.onFinish(result);
  }

  @override
  Future<WebSocketMessage> onMessage(WebSocketMessage message) async {
    if(message is FileQueryResults) {
      final remoteFile = message[_fileName];
      if(remoteFile == null) {
        _position = 0;
        _resume = false;
      }
      else if(remoteFile.size < _fileSize) { // TODO need some other checks - modified timestamp perhaps?
        final resolution = await onResume?.call();
        if(resolution == Resolution.replace) {
          _position = remoteFile.size;
          _resume = false;
        }
        else if(resolution == Resolution.resume) {
          _position = remoteFile.size;
          _resume = true;
        }
        else {
          finish(Done(1, 'partial file exists and resume not approved - task canceled'));
          return null;
        }
      }
      else if(remoteFile.size >= _fileSize) {
        final resume = (onReplace != null) ? (await onReplace()) : false;
        if(resume) {
          _position = 0;
          _resume = false;
        } else {
          finish(Done(1, 'file exists and replace not approved - task canceled'));
          return null;
        }
      }
      return FileSend(_fileName, _fileSize, _position, _resume);
    }
    if(message is Ready) {
      onStatus?.call(Status(position: _position, total: _fileSize));
      if(_position < _fileSize) {
        reader ??= await file.open(mode: FileMode.read);
        await reader.setPosition(_position);
        final read = await reader.readInto(_buffer);
        _position += read;
        return Data(_buffer.sublist(0, read));
      } else {
        return Done();
      }
    }
    return null;
  }

  @override
  Future<WebSocketMessage> onData(List<int> data) {
    throw UnimplementedError();
  }
}
