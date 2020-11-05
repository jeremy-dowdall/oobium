import 'dart:async';
import 'dart:convert';

import 'dart:io' if (dart.library.html) 'ws_html.dart';

abstract class BaseWebSocket {

  final WebSocket _ws;
  final _tasks = <Task>[];
  final _handlers = <TaskHandler>[];
  TaskHandler _dataHandler;
  StreamSubscription _wsSubscription;

  BaseWebSocket(this._ws);

  void addData(List<int> data) {
    _ws.add(data);
  }

  void addHandler(TaskHandler handler) {
    _handlers.add(handler);
  }

  void addMessage(WebSocketMessage message) {
    _ws.add(message.socketData);
  }

  Future<T> addTask<T extends WebSocketMessage>(Task<T> task) async {
    task._socket = this;
    _tasks.add(task);
    try {
      task.start();
      return await task.result;
    } finally {
      task._socket = null;
      _tasks.remove(task);
    }
  }

  void start() {
    _wsSubscription ??= _ws.listen(_onData, onError: _onError, onDone: _onDone);
  }

  void pause() {
    _wsSubscription?.pause();
  }

  void stop() {
    _wsSubscription?.cancel();
    _wsSubscription = null;
  }

  void close([int code, String reason]) {
    stop();
    _ws.close(code, reason);
  }

  void _onData(dynamic data) {
    if(data is String) {
      _handleMessage(data);
    }
    if(data is List<int>) {
      _handleData(data);
    }
  }
  void _onError(Object error, StackTrace stackTrace) {
    print('error: $error\n$stackTrace');
  }
  void _onDone() {
    // TODO necessary?
    _wsSubscription?.cancel();
    _wsSubscription = null;
  }

  Future<void> _handleMessage(String source) async {
    final json = jsonDecode(source);
    for(var handler in [..._tasks, ..._handlers]) {
      if(await _handle(handler, json)) {
        return;
      }
    }
  }

  Future<void> _handleData(List<int> data) async {
    assert(_dataHandler != null, 'received data with no active data handler');
    final result = await _dataHandler?.onData(data);
    print('$runtimeType onData.result = $result');
    addMessage(result);
  }

  Future<bool> _handle(TaskHandler handler, Map<String, dynamic> json) async {
    final message = handler.message(json);
    if(message != null) {
      if(message is Done) {
        _dataHandler = null;
        if(handler is Task) { handler.finish(); }
      } else {
        final result = await handler.onMessage(message);
        if(result != null) {
          _dataHandler = handler;
          addMessage(result);
        }
      }
      return true;
    }
    return false;
  }
}

abstract class Task<T extends WebSocketMessage> extends TaskHandler {

  BaseWebSocket _socket;
  void addMessage(WebSocketMessage message) => _socket.addMessage(message);
  void addData(List<int> data) => _socket.addData(data);

  void onStart();
  void start() {
    _completer = Completer<T>();
    onStart();
  }

  Future<WebSocketMessage> onFinish([WebSocketMessage result]) => Future.value(result);
  void finish([WebSocketMessage result]) async {
    _completer.complete(await onFinish(result));
  }

  Completer _completer;
  void complete(T result) {
    _completer.complete(result);
  }
  Future<T> get result => _completer.future;
}

abstract class TaskHandler {

  final Map<String, WebSocketMessage Function(Map data)> _builders = {};
  TaskHandler() {
    register<Done>((_) => Done());
    registerMessageBuilders();
  }

  Future<WebSocketMessage> onMessage(WebSocketMessage message);
  Future<WebSocketMessage> onData(List<int> data);
  void registerMessageBuilders();

  void register<T extends WebSocketMessage>(T Function(Map data) builder) {
    _builders[T.toString()] = builder;
  }

  WebSocketMessage message(Map<String, dynamic> json) {
    final type = json['type'];
    return _builders.containsKey(type) ? _builders[type](json['data']) : null;
  }
}

abstract class WebSocketMessage {

  final Map<String, dynamic> data;
  WebSocketMessage([this.data]);

  dynamic get socketData => jsonEncode({'type': runtimeType.toString(), 'data': data ?? {}});

  @override
  String toString() => '$runtimeType(${data ?? ''})';
}

class Data extends WebSocketMessage {
  @override final List<int> socketData;
  Data(this.socketData);
}
class Done extends WebSocketMessage {
  Done([int code, String reason]) : super({'code': code, 'reason': reason});
  static Done Function(Map data) builder = (data) => Done(data['code'] ?? 0, data['reason'] ?? 'success');
  int get code => data['code'];
  String get reason => data['reason'];
  bool get isSuccess => code == 0;
  bool get isNotSuccess => !isSuccess;
}
class Ready extends WebSocketMessage {
  static Ready Function(Map data) builder = (_) => Ready();
}
class Close extends WebSocketMessage {
  static Close Function(Map data) builder = (_) => Close();
}

class FileQuery extends WebSocketMessage {
  FileQuery(String fileName) : super({'fileName': fileName});
  String get fileName => data['fileName'];
  static FileQuery Function(Map data) builder = (data) => FileQuery(data['fileName']);
}
class FileQueryResults extends WebSocketMessage {
  FileQueryResults(List<RemoteFile> files) : super({'files': files});
  List<RemoteFile> get files => data['files'];
  RemoteFile operator [](String name) => files.firstWhere((f) => f.name == name, orElse: () => null);
  static FileQueryResults Function(Map data) builder = (data) {
    final files = data['files'];
    if(files is List) {
      return FileQueryResults(files.map((d) => RemoteFile(d['name'], d['size'])).toList());
    } else {
      return FileQueryResults([]);
    }
  };
}
class FileSend extends WebSocketMessage {
  FileSend(String fileName, int fileSize, [start = 0, resume = false]) : super({'fileName': fileName, 'fileSize': fileSize, 'start': start, 'resume': resume});
  String get fileName => data['fileName'];
  int get fileSize => data['fileSize'];
  int get start => data['start'];
  bool get resume => data['resume'];
  static FileSend Function(Map data) builder = (data) => FileSend(data['fileName'], data['fileSize'], data['start'], data['resume']);
}

class RemoteFile {
  final String name;
  final int size;
  RemoteFile(this.name, this.size);
  Map<String, dynamic> toJson() => {'name': name, 'size': size};
}
class RemoteDirectory {
  final String name;
  RemoteDirectory(this.name);
  Map<String, dynamic> toJson() => {'name': name};
}

