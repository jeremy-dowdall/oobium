import 'package:oobium_client/src/models.dart';

class ClientPersistor extends Persistor {

  @override
  Future<bool> any<T>(ModelContext context, Iterable<Where> conditions) {
    // TODO: implement any
    throw UnimplementedError();
  }

  @override
  Future<bool> delete(Model model, {Iterable inBatchWith}) {
    // TODO: implement delete
    throw UnimplementedError();
  }

  @override
  Future<bool> exists<T>(ModelContext context, String id) {
    // TODO: implement exists
    throw UnimplementedError();
  }

  @override
  Future<T> get<T>(ModelContext context, String id, {T orElse}) {
    // TODO: implement get
    throw UnimplementedError();
  }

  @override
  Future<List<T>> getAll<T>(ModelContext context, Iterable<Where> conditions) {
    // TODO: implement getAll
    throw UnimplementedError();
  }

  @override
  String newId<T>(ModelContext context) {
    // TODO: implement newId
    throw UnimplementedError();
  }

  @override
  Future<SaveResult> save(Model model, {List<Model> inBatchWith, List<Model> andDelete}) {
    // TODO: implement save
    throw UnimplementedError();
  }

  @override
  Stream<T> stream<T>(ModelContext context, String id, {void Function(T event) onData, Function onError, void Function() onDone, bool cancelOnError}) {
    // TODO: implement stream
    throw UnimplementedError();
  }

  @override
  Stream<List<T>> streamAll<T>(ModelContext context, Iterable<Where> conditions, {void Function(T event) onData, Function onError, void Function() onDone, bool cancelOnError}) {
    // TODO: implement streamAll
    throw UnimplementedError();
  }

}