import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:oobium_websocket/oobium_websocket.dart';
import 'package:tools_common/streams.dart';

statusHandlerBak(WsRequest req) async {
  await exec(req.socket, 'dart', ['--version']);
  return true;
}

Stream<List<int>> statusHandler(WsRequest req) {
  final controller = StreamController<List<int>>();
  Future(() async {
    await run(controller.sink, 'dart', ['--version']);
  }).whenComplete(() {
    controller.close();
  });
  return controller.stream;
}

Future<int> run(Sink<List<int>> sink, String executable, [List<String> args=const[]]) async {
  sink.writeln('$executable ${args.join(' ')}');
  final process = await Process.start(executable, args);
  process.stdout.listen((e) => sink.add(e));
  process.stderr.listen((e) => sink.add(e));
  return process.exitCode;
}

extension SinkX on Sink<List<int>> {
  void write(msg) {
    if(msg is List<int>) {
      return add(msg);
    }
    return add(utf8.encode('$msg'));
  }
  void writeln(msg) => write('$msg\n');
}

Future<int> exec(WsRequestSocket socket, String executable, [List<String> args=const[]]) async {
  socket.writeln('$executable ${args.join(' ')}');
  final process = await Process.start(executable, args);
  socket.write([process.stdout, process.stderr]);
  final code = await process.exitCode;
  await socket.flush();
  return code;
}

extension PrintX on WsRequestSocket {
  Future<void> write(msg) {
    if(msg is Stream<List<int>>) {
      return putStream('/print', msg);
    }
    if(msg is List<Stream<List<int>>>) {
      return putStream('/print', Streams(msg).all);
    }
    return putStream('/print', Stream.fromIterable([utf8.encode('$msg')]));
  }
  Future<void> writeln(msg) => write('$msg\n');
}
