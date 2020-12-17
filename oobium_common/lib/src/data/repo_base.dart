import 'package:oobium_common/src/database.dart';

class Repo {

  final String db;
  Repo(this.db);

  Future<Repo> open() => throw UnsupportedError('platform not supported');
  Future<void> close({bool cancel = false}) => throw UnsupportedError('platform not supported');

  Stream<DataRecord> get([int timestamp]) => throw UnsupportedError('platform not supported');
  void put(Stream<DataRecord> records) => throw UnsupportedError('platform not supported');
}
