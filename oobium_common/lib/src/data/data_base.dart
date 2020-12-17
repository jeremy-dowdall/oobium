class Data {

  final String path;
  Data(this.path);

  Future<void> create() => throw UnsupportedError('platform not supported');
  Future<void> destroy() => throw UnsupportedError('platform not supported');

}