import 'dart:async';
import 'dart:convert';

abstract class Task<T extends WebSocketMessage> extends TaskHandler {

  void addMessage(WebSocketMessage message) => null;// _socket.addMessage(message);
  void addData(List<int> data) => null;// _socket.addData(data);

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
    register<DoneMessage>((_) => DoneMessage());
    registerMessageBuilders();
  }

  Future<WebSocketMessage> onMessage(WebSocketMessage message);
  Future<WebSocketMessage> onData(List<int> data);
  void registerMessageBuilders();

  void register<T extends WebSocketMessage>(T Function(Map data) builder) {
    _builders[T.toString()] = builder;
  }

  WebSocketMessage parseMessage(Map<String, dynamic> json) {
    final type = json['type'];
    return _builders.containsKey(type) ? _builders[type](json['data']) : null;
  }
}

abstract class WebSocketMessage {
  dynamic get socketData => jsonEncode({'type': runtimeType.toString()});
}

class Data extends WebSocketMessage {
  @override final List<int> socketData;
  Data(this.socketData);
}
class JsonMessage extends WebSocketMessage {
  final Map<String, dynamic> data;
  JsonMessage([this.data]);
  @override dynamic get socketData => jsonEncode({'type': runtimeType.toString(), 'data': data ?? {}});
}
class DoneMessage extends JsonMessage {
  DoneMessage([int code, String reason]) : super({'code': code, 'reason': reason});
  static DoneMessage Function(Map data) builder = (data) => DoneMessage(data['code'] ?? 0, data['reason'] ?? 'success');
  int get code => data['code'];
  String get reason => data['reason'];
  bool get isSuccess => code == 0;
  bool get isNotSuccess => !isSuccess;
}
class ReadyMessage extends WebSocketMessage {
  static ReadyMessage Function(Map data) builder = (_) => ReadyMessage();
}
class CloseMessage extends WebSocketMessage {
  static CloseMessage Function(Map data) builder = (_) => CloseMessage();
}

class FileQueryMessage extends JsonMessage {
  FileQueryMessage(String fileName) : super({'fileName': fileName});
  String get fileName => data['fileName'];
  static FileQueryMessage Function(Map data) builder = (data) => FileQueryMessage(data['fileName']);
}
class FileQueryResultsMessage extends JsonMessage {
  FileQueryResultsMessage(List<RemoteFile> files) : super({'files': files});
  List<RemoteFile> get files => data['files'];
  RemoteFile operator [](String name) => files.firstWhere((f) => f.name == name, orElse: () => null);
  static FileQueryResultsMessage Function(Map data) builder = (data) {
    final files = data['files'];
    if(files is List) {
      return FileQueryResultsMessage(files.map((d) => RemoteFile(d['name'], d['size'])).toList());
    } else {
      return FileQueryResultsMessage([]);
    }
  };
}
class FileSendMessage extends JsonMessage {
  FileSendMessage(String fileName, int fileSize, [start = 0, resume = false]) : super({'fileName': fileName, 'fileSize': fileSize, 'start': start, 'resume': resume});
  String get fileName => data['fileName'];
  int get fileSize => data['fileSize'];
  int get start => data['start'];
  bool get resume => data['resume'];
  static FileSendMessage Function(Map data) builder = (data) => FileSendMessage(data['fileName'], data['fileSize'], data['start'], data['resume']);
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

