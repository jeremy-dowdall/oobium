import 'package:oobium_common/src/database.dart';

class Repo {

  final String path;
  Repo(this.path);

  Future<void> open() => throw UnsupportedError('platform not supported');
  Future<void> close() => throw UnsupportedError('platform not supported');
  Future<void> destroy() => throw UnsupportedError('platform not supported');

  Stream<DataRecord> read() => throw UnsupportedError('platform not supported');
  void write(Iterable<DataRecord> records) => throw UnsupportedError('platform not supported');
  Future<void> writeStream(Stream<String> lines) => throw UnsupportedError('platform not supported');
}
