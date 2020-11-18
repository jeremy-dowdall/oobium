import 'dart:async';
import 'dart:io';

import 'package:objectid/objectid.dart';
import 'package:oobium_common/src/json.dart';
import 'package:oobium_common/src/string.extensions.dart';

class Database {

  final String path;
  Database(this.path);

  final _models = <String, JsonModel>{};
  int _puts;
  IOSink _sink;
  StreamController _controller;
  StreamSubscription _subscription;
  Completer<void> _completer;

  void addBuilder<T>(T builder(Map data)) => _builders[T.toString()] = builder;

  Future<void> open() async {
    if(_sink != null) {
      return;
    }
    await Directory(path).parent.create(recursive: true);
    final file = File(path);
    if(await file.exists()) {
      final lines = await file.readAsLines();
      _puts = lines.length;
      for(var line in lines) {
        final item = Json.decode(line);
        _models[item['k']] = _build(item['t'], item['v']..['id'] = item['k']);
      }
    } else {
      _puts = 0;
    }
    _sink = file.openWrite(mode: FileMode.writeOnlyAppend);
    _controller = StreamController(sync: true);
    _subscription = _controller.stream.listen(_sink.writeln);
    // _subscription = _controller.stream.listen((data) {
      // print('write');
      // _sink.writeln(data);
      // _lineCount++;
      // print('wrote');
    // });
  }

  Future<void> flush() async {
    print('flush');
    await _completer?.future;
    print('complete');
    await _sink?.flush();
    print('flushed');
  }
  Future<void> close() async {
    print('close');
    await flush();
    await _subscription?.cancel();
    await _controller?.close();
    await _sink?.close();
    _sink = null;
    _controller = null;
    _subscription = null;
    _models.clear();
    _puts = 0;
    print('closed');
  }

  Future<void> destroy() async {
    await close();
    await File(path).delete();
  }

  Future<void> reset() async {
    await destroy();
    await open();
  }

  T get<T extends JsonModel>(String id, {T Function() orElse}) {
    if(_models.containsKey(id)) {
      return _models[id] as T;
    }
    return orElse?.call();
  }

  T put<T extends JsonModel>(T model) {
    _puts++;
    if(_models[model.id] == model) {
      return model;
    }
    final type = model.runtimeType.toString();
    final data = _toJson(model);
    final update = model.id.isBlank ? (_build(type, data) as T) : model;
    _models[update.id] = update;
    _controller.add(Json.encode({'t': type, 'k': data.remove('id'), 'v': data}));
    _checkCompact();
    return update;
  }

  int get fileSize => _puts;
  int get percentObsolete => (size > 0) ? (100 * (fileSize - size) ~/ fileSize) : 0;
  int get size => _models.length;

  bool get isCompacting => _subscription.isPaused;
  bool get isNotCompacting => !isCompacting;
  bool get _shouldCompact => isNotCompacting && (size >= 6) && (percentObsolete >= 20);

  void _checkCompact() {
    if(_shouldCompact) {
      _completer = Completer();
      _compact().then((_) {
        _completer.complete();
      });
    }
  }
  Future<void> _compact() async {
    print('compact');
    _subscription.pause();
    final file = File('$path.tmp');
    final sink = file.openWrite(mode: FileMode.writeOnly);
    for(var model in _models.values) {
      final type = model.runtimeType.toString();
      final data = _toJson(model);
      sink.writeln(Json.encode({'t': type, 'k': data.remove('id'), 'v': data}));
    }
    await sink.flush();
    await sink.close();
    await _sink.close();
    await _sink.close();
    _sink = (await file.rename(path)).openWrite(mode: FileMode.writeOnlyAppend);;
    _subscription.resume();
    print('compacted');
  }

  final _builders = <String, Function(Map data)>{};
  dynamic _build(String type, Map data) {
    assert(_builders[type] != null, 'no builder registered for $type');
    return _builders[type](data);
  }

  String _createId() {
    return ObjectId().hexString;
  }

  Map _toJson(JsonModel model) => model.toJson()
    ..['id'] = model.id.isBlank ? _createId() : model.id
    ..removeWhere((k,v) => k == null || v == null || (v is String && v.isEmpty) || (v is Map && v.isEmpty) || (v is Iterable && v.isEmpty))
  ;
}