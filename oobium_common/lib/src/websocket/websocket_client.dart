import 'dart:async';
import 'dart:io' if (dart.library.html) 'ws_html.dart';

import 'package:oobium_common/src/websocket/websocket_bak.dart';

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
    register<ReadyMessage>(ReadyMessage.builder);
    register<FileQueryResultsMessage>(FileQueryResultsMessage.builder);
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
    addMessage(FileQueryMessage(_fileName));
  }

  @override
  Future<WebSocketMessage> onFinish([WebSocketMessage result]) async {
    await reader.close();
    return super.onFinish(result);
  }

  @override
  Future<WebSocketMessage> onMessage(WebSocketMessage message) async {
    if(message is FileQueryResultsMessage) {
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
          finish(DoneMessage(1, 'partial file exists and resume not approved - task canceled'));
          return null;
        }
      }
      else if(remoteFile.size >= _fileSize) {
        final resume = (onReplace != null) ? (await onReplace()) : false;
        if(resume) {
          _position = 0;
          _resume = false;
        } else {
          finish(DoneMessage(1, 'file exists and replace not approved - task canceled'));
          return null;
        }
      }
      return FileSendMessage(_fileName, _fileSize, _position, _resume);
    }
    if(message is ReadyMessage) {
      onStatus?.call(Status(position: _position, total: _fileSize));
      if(_position < _fileSize) {
        reader ??= await file.open(mode: FileMode.read);
        await reader.setPosition(_position);
        final read = await reader.readInto(_buffer);
        _position += read;
        return Data(_buffer.sublist(0, read));
      } else {
        return DoneMessage();
      }
    }
    return null;
  }

  @override
  Future<WebSocketMessage> onData(List<int> data) {
    throw UnimplementedError();
  }
}
