import 'dart:async';
import 'dart:isolate';

import 'package:oobium/src/datastore.dart';
import 'package:oobium/src/datastore/data.dart';
import 'package:oobium/src/datastore/executor.dart';
import 'package:oobium/src/datastore/repo.dart';
import 'package:stream_channel/isolate_channel.dart';
import 'package:stream_channel/stream_channel.dart';

void workers(SendPort port) {
  print('isolate runner active');
  final channel = IsolateChannel.connectSend(port);
  final server = DataWorkerServer(channel);
  server.start();
}

class DataIsolate {

  static final _isolates = <String, DataIsolate>{};

  static Future<DataIsolate> of(String name) async {
    if(_isolates.containsKey(name)) {
      return _isolates[name]!;
    } else {
      final port = ReceivePort();
      final isolate = await Isolate.spawn(workers, port.sendPort);
      final channel = IsolateChannel.connectReceive(port);
      return _isolates[name] = DataIsolate._(name, isolate, channel);
    }
  }

  final String name;
  final Isolate _isolate;
  final StreamChannel _channel;
  final _executor = Executor();
  DataIsolate._(this.name, this._isolate, this._channel) {
    _channel.stream.listen(_onData, onError: _onError);
  }

  Future<T> send<T>(cmd) async {
    return _executor.add<T>((_) async {
      _channel.sink.add(cmd);
      final result = await next;
      return result as T;
    });
  }

  Completer? _next;
  Future get next => (_next = Completer()).future;

  StreamController<DataRecord>? _data;
  Stream<DataRecord> get data => (_data = StreamController()).stream;

  void _onData(data) {
    if(_next?.isCompleted == false) {
      _next!.complete(data);
      _next = null;
      return;
    }
    if(_data != null) {
      if(data is DataRecord) {
        _data!.add(data);
      } else {
        _data!.close();
        _data = null;
      }
      return;
    }
  }

  void _onError(error, stack) {
    print('$error\n$stack');
  }
}

class DataWorkerServer {

  var count = 0;
  final workers = <int, DataWorker>{};
  final StreamChannel channel;
  DataWorkerServer(this.channel);

  void start() {
    channel.stream.listen((event) {
      final cmd = event as List;
      final op = cmd[0];
      final worker = (cmd.length > 1) ? workers[cmd[1]] : null;
      print('received: [${cmd.take(2).join(', ')}${cmd.length>2?', ${cmd[2]?.length}':''}]');
      switch(op) {
        case 'open':
          final port = count++;
          DataWorker(cmd[1]).open().then((w) {
            workers[port] = w;
            channel.sink.add(port);
          });
          break;
        case 'flush': return _execute(worker, (w) {
          return w.flush();
        });
        case 'close': return _execute(worker, (w) {
          workers.remove(cmd[1]);
          return w.close();
        });
        case 'destroy': return _execute(worker, (w) {
          return w.destroy();
        });
        case 'data_get': return _execute(worker, (w) {
          channel.sink.add('ready');
          return channel.sink.addStream(w.getData()).then((_) => 'done');
        });
        case 'data_put': return _execute(worker, (w) {
          return w.putData(
            update: cmd[2] as Iterable<DataRecord>?,
            reset: cmd[3] as Iterable<DataRecord>?
          );
        });
      }
    });
  }

  void _execute(DataWorker? worker, FutureOr Function(DataWorker w) f) {
    if(worker == null) {
      print('worker not found');
    } else {
      try {
        Future.value(f(worker)).then((result) => channel.sink.add(result));
      } catch(e,s) {
        print('$e\n$s');
        throw e;
      }
    }
  }
}

abstract class DataWorker {
  factory DataWorker(String path, {String? isolate}) {
    if(isolate == null) {
      return DataWorkerRunner(path);
    } else {
      return DataWorkerClient(isolate, path);
    }
  }
  String get path;
  int get version;
  bool get isOpen;
  bool get isNotOpen;
  Future<DataWorker> open({int version=1, Stream<DataRecord> Function(UpgradeEvent event)? onUpgrade});
  Future<void> flush();
  Future<void> close();
  Future<void> destroy();
  Stream<DataRecord> getData();
  Future<void> putData({Iterable<DataRecord>? update, Iterable<DataRecord>? reset});
}

class DataWorkerClient implements DataWorker {
  final String isolate;
  final String path;
  DataWorkerClient(this.isolate, this.path);

  late DataIsolate _dataIsolate;
  late int _port;

  int _version = 0;
  int get version => _version;

  bool _open = false;
  bool get isOpen => _open;
  bool get isNotOpen => !isOpen;

  Future<DataWorker> open({int version=1, Stream<DataRecord> Function(UpgradeEvent event)? onUpgrade}) async {
    assert(isNotOpen);
    _open = true;
    _dataIsolate = await DataIsolate.of(isolate);
    // TODO does upgrade need to happen here? don't think we can pass onUpgrade to the other side...
    _port = await _dataIsolate.send<int>(['open', path]);
    return this;
  }

  @override
  Future<void> flush() {
    assert(isOpen);
    return _dataIsolate.send(['flush', _port]);
  }

  @override
  Future<void> close() {
    assert(isOpen);
    _open = false;
    return _dataIsolate.send(['close', _port]);
  }

  @override
  Future<void> destroy() {
    assert(isOpen);
    _open = false;
    return _dataIsolate.send(['destroy', _port]);
  }

  @override
  Stream<DataRecord> getData() {
    _dataIsolate.send(['data_get', _port]);
    return _dataIsolate.data;
  }

  @override
  Future<void> putData({Iterable<DataRecord>? update, Iterable<DataRecord>? reset}) {
    return _dataIsolate.send(['data_put', _port, update, reset]);
  }
}

class DataWorkerRunner implements DataWorker {
  final String path;
  late Data _data;
  late Repo _repo;
  // Sync sync;
  DataWorkerRunner(this.path);

  int _version = 0;
  int get version => _version;

  bool _open = false;
  bool get isOpen => _open;
  bool get isNotOpen => !isOpen;

  Future<DataWorker> open({int version=1, Stream<DataRecord> Function(UpgradeEvent event)? onUpgrade}) async {
    assert(isNotOpen);
    _open = true;
    _version = version;
    _data = await Data(path).open(version: version, onUpgrade: (event) async {
      if(onUpgrade != null) {
        final oldRepo = (event.oldData != null) ? (await Repo(event.oldData!).open()) : null;
        final stream = onUpgrade(UpgradeEvent(event.oldVersion, event.newVersion, oldRepo?.get() ?? Stream<DataRecord>.empty()));
        final newRepo = await Repo(event.newData).open();
        newRepo.put(stream);
        await newRepo.flush();
        await newRepo.close();
        await oldRepo?.close();
      }
      return true;
    });
    _repo = await Repo(_data).open();
    return this;
  }

  Future<void> flush() async {
    assert(isOpen);
    await _repo.flush();
  }

  Future<void> close() async {
    assert(isOpen);
    await _repo.flush();
    await _repo.close();
    await _data.close();
  }

  Future<void> destroy() async {
    assert(isOpen);
    await _repo.close();
    await _data.destroy();
  }

  Stream<DataRecord> getData() {
    assert(isOpen);
    return _repo.get();
  }

  Future<void> putData({Iterable<DataRecord>? update, Iterable<DataRecord>? reset}) async {
    assert(isOpen);
    if(reset != null) {
      await _repo.reset(reset);
    }
    if(update != null) {
      await _repo.putAll(update);
    // await _sync.putAll(records);
    }
  }
}