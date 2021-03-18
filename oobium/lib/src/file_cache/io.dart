import 'dart:io';

import 'package:http_parser/http_parser.dart';
import 'package:oobium/src/file_cache/unsupported.dart';

class FileCache implements IFileCache {

  final String path;
  final Map<String, _FileItem> _items = {};
  int _size = 0;
  FileCache(this.path);

  String get _metaPath => '$path/meta';
  String get _dataPath => '$path/data';
  int get size => _size;

  Future<FileCache> init() async {
    await Directory(_metaPath).create(recursive: true);
    await Directory(_dataPath).create(recursive: true);
    await load();
    return this;
  }

  Future<FileCache> load() async {
    _items.clear();
    _size = 0;
    final files = await Directory(_metaPath).list(recursive: true).toList();
    await Future.forEach(files.whereType<File>(), (f) async {
      final meta = await f.readAsLines();
      final item = _FileItem.fromMeta(this, meta);
      _items[item.path] = item;
      _size += item.size;
    });
    return this;
  }

  Future<void> destroy() async {
    await Directory(path).delete(recursive: true);
    _items.clear();
    _size = 0;
  }

  Future<FileCache> reset() async {
    await Directory(path).delete(recursive: true);
    await Directory(_metaPath).create(recursive: true);
    await Directory(_dataPath).create(recursive: true);
    _items.clear();
    _size = 0;
    return this;
  }

  Future<String> get(String path) async => _items[path]?.read();

  bool isExpired(String path) => _items[path] == null || _items[path].isExpired;

  Future<void> put(String path, String data, {
    Duration expiresIn,
    DateTime expiresAt,
    String expiresAtHttpDate
  }) async {
    final previous = _items[path];
    if(previous != null) {
      _size -= previous.size;
      if(data == null) {
        await _items.remove(path).delete();
      }
    }

    if(data != null) {
      final item = _FileItem(this, path, _expiresAt(expiresIn, expiresAt, expiresAtHttpDate));
      await item.write(data);
      _size += item.size;
      _items[path] = item;
    }
  }

  static DateTime _expiresAt(Duration expiresIn, DateTime expiresAt, String httpDate) {
    if(expiresAt != null) return DateTime.fromMillisecondsSinceEpoch(expiresAt.millisecondsSinceEpoch);
    if(httpDate  != null) return parseHttpDate(httpDate);
    if(expiresIn != null) return DateTime.now().add(expiresIn);
    return null;
  }

  Future<void> remove(String path) => put(path, null);
}

class _FileItem {
  final FileCache cache;
  final String path;
  final DateTime expiresAt;
  int size;

  _FileItem(this.cache, this.path, this.expiresAt);
  _FileItem.fromMeta(this.cache, List<String> meta) :
        path = meta[0],
        expiresAt = (meta[1] != 'null') ? DateTime.fromMillisecondsSinceEpoch(int.parse(meta[1])) : null,
        size = int.parse(meta[2]);

  String get meta => '$path\n${expiresAt?.millisecondsSinceEpoch}\n${size??0}';

  bool get isExpired => expiresAt != null && expiresAt.isBefore(DateTime.now());

  String get metaPath => '${cache._metaPath}/$path.meta';
  String get dataPath => '${cache._dataPath}/$path.json';

  Future<String> read() async {
    return File(dataPath).readAsString();
  }

  Future<void> write(String data) async {
    size = meta.length + data.length;
    size = size + size.toString().length - 1;
    await Directory(metaPath).parent.create(recursive: true);
    await Directory(dataPath).parent.create(recursive: true);
    await File(metaPath).writeAsString(meta);
    await File(dataPath).writeAsString(data);
  }

  Future<void> delete() async {
    await File(metaPath).delete();
    await File(dataPath).delete();
  }
}
