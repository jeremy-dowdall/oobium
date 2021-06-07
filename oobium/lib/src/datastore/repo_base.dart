import 'package:oobium/src/datastore/data.dart';
import 'package:oobium/src/datastore/executor.dart';
import 'package:oobium/src/datastore.dart';

class Repo implements Connection {

  final Data data;
  var executor = Executor();
  Repo(this.data);

  Future<Repo> open() => throw UnsupportedError('platform not supported');
  Future<void> flush() => executor.flush();
  Future<void> close() => executor.cancel();

  Stream<DataRecord> get([int? timestamp]) => throw UnsupportedError('platform not supported');
  Future<void> put(Stream<DataRecord> records) => throw UnsupportedError('platform not supported');
  Future<void> putAll(Iterable<DataRecord> records) => throw UnsupportedError('platform not supported');

  Future<void> reset(Iterable<DataRecord> records) => throw UnsupportedError('platform not supported');
}
