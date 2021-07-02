import 'dart:async';
import 'dart:convert';

import 'dart:io';

Stream<List<int>> run(String executable, List<String> args, {
  bool echo=false,
  String? workingDirectory
}) async* {
  if(echo) {
    yield line('$executable ${args.join(' ')}');
  }
  final process = await Process.start(executable, args, workingDirectory: workingDirectory);
  yield* process.stdout;
  yield* process.stderr;
  final code = await process.exitCode;
  if(code != 0) {
    throw 'exit($code)';
  }
}

List<int> text([msg]) => (msg == null) ? [] : utf8.encode('$msg');
List<int> line([msg]) => (msg == null) ? [10] : text('$msg\n');
