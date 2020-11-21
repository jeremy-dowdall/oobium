import 'dart:async';
import 'dart:io';

import 'package:objectid/objectid.dart';
import 'package:oobium_common/src/json.dart';
import 'package:oobium_common/src/string.extensions.dart';

class Database {

  final String path;
  Database(this.path);

  final _builders = <String, Function(Map data)>{};
  final _models = <String, JsonModel>{};
  int _fileSize;
  IOSink _sink;
  Completer<void> _compactCompleter;
  List<String> _commitBuffer;
  bool _inBatch = false;

  void addBuilder<T>(T builder(Map data)) {
    _builders[T.toString()] = builder;
  }

  Future<void> open() async {
    if(_sink != null) {
      return;
    }
    await Directory(path).parent.create(recursive: true);
    final file = File(path);
    if(await file.exists()) {
      final lines = await file.readAsLines();
      _fileSize = lines.length;
      for(var line in lines) {
        final item = Json.decode(line);
        if(item is Map) {
          final id = item['k'];
          if(id is String && id.isNotEmpty) {
            final type = item['t'];
            final data = item['v'];
            if((type is String && type.isNotEmpty) && (data is Map)) {
              _models[id] = _build(type, data..['id'] = id);
            } else {
              _models.remove(id);
            }
          }
        }
      }
    } else {
      _fileSize = 0;
    }
    _sink = file.openWrite(mode: FileMode.writeOnlyAppend);
  }

  Future<void> flush() async {
    await _compactCompleter?.future;
    await _sink?.flush();
  }
  
  Future<void> close() async {
    await flush();
    await _sink?.close();
    _sink = null;
    _models.clear();
    _fileSize = 0;
  }

  Future<void> destroy() async {
    await close();
    await File(path).delete();
  }

  Future<void> reset() async {
    await destroy();
    await open();
  }

  String newId() {
    return ObjectId().hexString;
  }

  T get<T extends JsonModel>(String id, {T Function() orElse}) {
    if(_models.containsKey(id)) {
      return _models[id] as T;
    }
    return orElse?.call();
  }

  Iterable<T> getAll<T extends JsonModel>() {
    return _models.values.whereType<T>();
  }

  List<T> batch<T extends JsonModel>({Iterable<T> put, Iterable<String> remove}) {
    try {
      _batch = true;
      final results = put.map((model) => _put(model)).toList();
      for(var id in remove) _remove(id);
      return results;
    } finally {
      _batch = false;
    }
  }
  
  T put<T extends JsonModel>(T model) {
    return _put(model);
  }
  List<T> putAll<T extends JsonModel>(Iterable<T> models) {
    try {
      _batch = true;
      return models.map((model) => _put(model)).toList();
    } finally {
      _batch = false;
    }
  }

  void remove(String id) {
    _remove(id);
  }
  void removeAll(Iterable<String> ids) {
    try {
      _batch = true;
      for(var id in ids) _remove(id);
    } finally {
      _batch = false;
    }
  }
  
  void _commit({String type, String key, Map value}) {
    _fileSize++;
    final doc = Json.encode({'t': type, 'k': key, 'v': value}..removeWhere((k,v) => v == null));
    if(isCompacting) {
      _commitBuffer.add(doc);
    } else {
      _sink.writeln(doc);
    }
  }

  T _put<T extends JsonModel>(T model) {
    if(model.isSameAs(_models[model.id])) {
      return model;
    }
    final type = model.runtimeType.toString();
    final data = _toJson(model);
    final update = model.id.isBlank ? (_build(type, data) as T) : model;
    _models[update.id] = update;
    if(_shouldCompact) {
      compact();
    } else {
      _commit(type: type, key: data.remove('id'), value: data);
    }
    // print('records: ${size}, obsolete: ${percentObsolete}%');
    return update;
  }
  
  void _remove(String id) {
    if(_models.containsKey(id)) {
      _models.remove(id);
      if(_shouldCompact) {
        compact();
      } else {
        _commit(key: id);
      }
      // print('records: ${size}, obsolete: ${percentObsolete}%');
    }
  }

  int get fileSize => _fileSize;
  int get percentObsolete => (size > 0) ? (100 * (fileSize - size) ~/ fileSize) : 0;
  int get size => _models.length;

  bool get isCompacting => _compactCompleter != null && !_compactCompleter.isCompleted;
  bool get isNotCompacting => !isCompacting;
  bool get _shouldCompact => !_inBatch && (size >= 6) && (percentObsolete >= 20);

  Future<void> compact() {
    _compactCompleter = Completer();
    return _compact().then(_compactCompleter.complete);
  }
  Future<void> _compact() async {
    _commitBuffer = [];
    _fileSize = size;
    final file = File('$path.tmp');
    final sink = file.openWrite(mode: FileMode.writeOnly);
    for(var model in _models.values) {
      final type = model.runtimeType.toString();
      final data = _toJson(model);
      sink.writeln(Json.encode({'t': type, 'k': data.remove('id'), 'v': data}));
    }
    await sink.flush();
    await sink.close();
    await _sink.flush();
    await _sink.close();
    _sink = (await file.rename(path)).openWrite(mode: FileMode.writeOnlyAppend);;
    for(var doc in _commitBuffer) {
      _sink.writeln(doc);
    }
    _commitBuffer = null;
    if(_shouldCompact) {
      return _compact();
    }
  }

  set _batch(bool value) {
    if(value != _inBatch) {
      _inBatch = value;
      if(value && _shouldCompact) {
        compact();
      }
    }
  }

  dynamic _build(String type, Map data) {
    assert(_builders[type] != null, 'no builder registered for $type');
    return _builders[type](data);
  }

  Map _toJson(JsonModel model) => model.toJson()
    ..['id'] = model.id.isBlank ? newId() : model.id
    ..removeWhere((k,v) => k == null || v == null || (v is String && v.isEmpty) || (v is Map && v.isEmpty) || (v is Iterable && v.isEmpty))
  ;
}
