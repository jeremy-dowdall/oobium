abstract class IFileCache {

  IFileCache(String path);

  int get size;

  Future<IFileCache> init();
  Future<IFileCache> load();
  Future<IFileCache> reset();
  Future<void> destroy();

  bool isExpired(String path);

  Future<String> get(String path);
  Future<void> put(String path, String data, {Duration expiresIn, DateTime expiresAt, String expiresAtHttpDate});
  Future<void> remove(String path) => put(path, null);
}
