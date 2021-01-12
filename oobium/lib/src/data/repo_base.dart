import 'package:oobium/src/data/data.dart';
import 'package:oobium/src/data/executor.dart';
import 'package:oobium/src/database.dart';

class Repo implements Connection {

  final Data db;
  final executor = Executor();
  Repo(this.db);

  Future<Repo> open() => throw UnsupportedError('platform not supported');
  Future<void> flush() => executor.close(cancel: false);
  Future<void> close({bool cancel = false}) => executor.close(cancel: cancel ?? false);

  Stream<DataRecord> get([int timestamp]) => throw UnsupportedError('platform not supported');
  Future<void> put(Stream<DataRecord> records) => throw UnsupportedError('platform not supported');
  Future<void> putAll(Iterable<DataRecord> records) => throw UnsupportedError('platform not supported');
}
