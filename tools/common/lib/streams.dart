import 'dart:async';

import 'dart:convert';
import 'dart:io';

import 'package:tools_common/processes.dart';

Stream<List<int>> streamFiles(Map<String, File> files) async* {
  for(final entry in files.entries) {
    final path = entry.key;
    final file = entry.value;
    final size = file.statSync().size;
    print('$path:$size');
    yield line('$path:$size');
    yield* file.openRead();
  }
}

class FileStreamConsumer implements StreamConsumer<List<int>> {

  final Directory _dir;
  final Function(String msg) onMessage;
  FileStreamConsumer(Directory? dir, this.onMessage) : _dir = dir ?? Directory.current;

  @override
  Future<void> addStream(Stream<List<int>> stream) => (_sub = stream.listen(
      onData, onError: onError, onDone: onDone, cancelOnError: true
  )).asFuture();
  StreamSubscription? _sub;

  @override
  Future<void> close() async {
    await _sub?.cancel();
    await _sink?.flush();
    await _sink?.close();
    _sub = null;
    _sink = null;
  }

  var _todo = 0;
  IOSink? _sink;
  List<int>? _buff;
  void onData(List<int> data) {
    if(_buff != null) {
      data = [..._buff!, ...data];
    }
    if(_sink == null) {
      final pathStart = 0, pathEnd = data.indexOf(58);
      final sizeStart = pathEnd + 1, sizeEnd = data.indexOf(10, pathEnd);
      final dataStart = sizeEnd + 1, dataEnd = data.length;
      final path = utf8.decode(data.sublist(pathStart, pathEnd));
      final size = utf8.decode(data.sublist(sizeStart, sizeEnd));
      _todo = int.parse(size);
      // onMessage('starting $path($size)');
      final file = File('${_dir.path}/$path');
      file.createSync(recursive: true);
      final sink = _sink = file.openWrite();
      if(dataStart < dataEnd) {
        sink.add(data.sublist(dataStart));
        _todo -= (dataEnd - dataStart);
      }
    } else {
      if(_todo < data.length) {
        _sink!.add(data.sublist(0, _todo));
        _buff = data.sublist(_todo);
        _todo = 0;
      } else {
        _sink!.add(data);
        _todo -= data.length;
      }
      if(_todo == 0) {
        _close(_sink!);
        _sink = null;
        // onMessage('  finished.');
      }
    }
  }
  Future<void> _close(IOSink sink) => sink.flush().then((_) => sink.close());

  void onError(e, s) => print('$e\n$s');
  void onDone() => close();
}

class Streams<T> {
  final _streams = <Stream<T>>[];
  final _subs = <Stream<T>, StreamSubscription<T>>{};
  final _controller = StreamController<T>();
  final bool _autoClose;

  Streams([List<Stream<T>>? streams]) : _autoClose = streams != null {
    if(streams != null) {
      for(final stream in streams) {
        add(stream);
      }
    }
  }

  void add(Stream<T> stream) {
    _streams.add(stream);
    _subs[stream] = stream.listen(
        (e) => _controller.add(e),
        onError: (err) => remove(stream),
        onDone: () => remove(stream)
    );
  }

  Future<void> remove(Stream<T> stream) async {
    await _subs.remove(stream)?.cancel();
    if(_autoClose && _subs.isEmpty && !_controller.isClosed) {
      await _controller.close();
    }
  }

  Future<void> close() => Future.forEach<Stream<T>>(_streams.toList(), (stream) => remove(stream));

  Stream<T> get all => _controller.stream;
}