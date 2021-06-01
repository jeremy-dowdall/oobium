import 'package:oobium/src/file_cache/unsupported.dart';

class FileCache implements IFileCache {

  final String path;
  FileCache(this.path);

  @override
  Future<void> destroy() async { }

  @override
  Future<String?> get(String path) async => null;

  @override
  Future<FileCache> init() async => this;

  @override
  bool isExpired(String path) => true;

  @override
  Future<FileCache> load() async => this;

  @override
  Future<void> put(String path, String? data, {Duration? expiresIn, DateTime? expiresAt, String? expiresAtHttpDate}) async { }

  @override
  Future<void> remove(String path) async { }

  @override
  Future<FileCache> reset() async => this;

  @override
  int get size => 0;

}