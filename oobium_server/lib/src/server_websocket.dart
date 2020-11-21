import 'dart:io';
import 'dart:async';

import 'package:meta/meta.dart';
import 'package:oobium_common/oobium_common.dart';

class FileQueryHandler extends TaskHandler {

  final String path;
  FileQueryHandler(this.path);

  @override
  void registerMessageBuilders() {
    register<FileQueryMessage>(FileQueryMessage.builder);
  }

  @override
  Future<WebSocketMessage> onMessage(WebSocketMessage message) async {
    // print('$runtimeType onMessage($message)');
    if(message is FileQueryMessage) {
      final results = <RemoteFile>[];
      final file = File('$path/${message.fileName}');
      if(await file.exists()) {
        final stat = await file.stat();
        results.add(RemoteFile(message.fileName, stat.size));
      }
      return FileQueryResultsMessage(results);
    }
    return DoneMessage();
  }

  @override
  Future<WebSocketMessage> onData(List<int> data) {
    throw UnimplementedError();
  }
}

class FileSendHandler extends TaskHandler {

  final String _path;
  FileSendHandler(this._path);

  ServerFileWriter _writer;

  @override
  void registerMessageBuilders() {
    register<FileSendMessage>(FileSendMessage.builder);
  }

  @override
  Future<WebSocketMessage> onMessage(WebSocketMessage message) async {
    if(message is FileSendMessage) {
      // TODO not a safe path
      final file = File('$_path/${message.fileName}');
      _writer = ServerFileWriter(file: file, total: message.fileSize, start: message.start, resume: message.resume);
      return ReadyMessage();
    }
    return null;
  }

  @override
  Future<WebSocketMessage> onData(List<int> data) async {
    return (await _writer.write(data)) ? DoneMessage() : ReadyMessage();
  }
}

class ServerFileWriter {
  final IOSink writer;
  final int total;
  int position;

  ServerFileWriter._({this.writer, this.total, this.position = 0});
  factory ServerFileWriter({@required File file, @required int total, start = 0, resume = false}) {
    final writer = file.openWrite(mode: resume ? FileMode.writeOnlyAppend : FileMode.writeOnly);
    return ServerFileWriter._(writer: writer, total: total, position: start);
  }

  int get percentDone => 100 * position ~/ total;

  Future<bool> write(List<int> msg) async {
    writer.add(msg);
    position += msg.length;
    if(position >= total) {
      if(position > total) {
        print('hmmm... wrote: $position but total is only: $total');
      }
      print('finished reading data... flushing file');
      await writer.flush();
      print('file flushed... closing');
      await writer.close();
      print('all done :)');
      return true;
    }
    return false;
  }
}