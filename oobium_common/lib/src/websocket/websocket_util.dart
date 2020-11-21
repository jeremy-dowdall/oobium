import 'dart:io';
import 'dart:math';

import 'package:meta/meta.dart';
import 'package:oobium_common/src/json.dart';

class FileSend extends Json {

  final Map<String, dynamic> data;
  FileSend(String fileName, int fileSize, [start = 0, resume = false]) :
    data = {'fileName': fileName, 'fileSize': fileSize, 'start': start, 'resume': resume};
  FileSend.fromJson(this.data);

  String get fileName => data['fileName'];
  int get fileSize => data['fileSize'];
  int get start => data['start'];
  bool get resume => data['resume'];

  @override
  Map<String, dynamic> toJson() => data;
}

class FileSender {
  WebSocket ws;
  File file;
  int _size;
  int _position;

  final bufferSize = 1024*1024;
  Future<void> sendNext() {
    if(_position < _size) {
      final end = min(_position + bufferSize, _size);
      final stream = file.openRead(_position, _position + bufferSize);
      _position = end;
      return stream.toList().then((lists) {
        for(var list in lists) {
          ws.add(list);
        }
      });
    } else {
      return Future.value();
    }
  }
}

class FileReceiver {
  final IOSink writer;
  final int total;
  int position;

  FileReceiver._({this.writer, this.total, this.position = 0});
  factory FileReceiver({@required File file, @required int total, start = 0, resume = false}) {
    final writer = file.openWrite(mode: resume ? FileMode.writeOnlyAppend : FileMode.writeOnly);
    return FileReceiver._(writer: writer, total: total, position: start);
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