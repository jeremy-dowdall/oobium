import 'package:oobium_datastore/oobium_datastore.dart';

class MainData {
  final DataStore _ds;
  MainData(String path, {String? isolate})
      : _ds = DataStore('$path/main', isolate: isolate, builders: [
          (data) => Author.fromJson(data),
          (data) => Book.fromJson(data)
        ], indexes: []);
  Future<MainData> open(
          {int version = 1,
          Stream<DataRecord> Function(UpgradeEvent event)? onUpgrade}) =>
      _ds.open(version: version, onUpgrade: onUpgrade).then((_) => this);
  Future<void> flush() => _ds.flush();
  Future<void> close() => _ds.close();
  Future<void> destroy() => _ds.destroy();
  bool get isEmpty => _ds.isEmpty;
  bool get isNotEmpty => _ds.isNotEmpty;
  Author? getAuthor(ObjectId? id, {Author? Function()? orElse}) =>
      _ds.get<Author>(id, orElse: orElse);
  Book? getBook(ObjectId? id, {Book? Function()? orElse}) =>
      _ds.get<Book>(id, orElse: orElse);
  Iterable<Author> getAuthors() => _ds.getAll<Author>();
  Iterable<Book> getBooks() => _ds.getAll<Book>();
  Iterable<Author> findAuthors({String? name}) =>
      _ds.getAll<Author>().where((m) => (name == null || name == m.name));
  Iterable<Book> findBooks({String? title, Author? author}) =>
      _ds.getAll<Book>().where((m) =>
          (title == null || title == m.title) &&
          (author == null || author == m.author));
  T put<T extends MainModel>(T model) => _ds.put<T>(model);
  List<T> putAll<T extends MainModel>(Iterable<T> models) =>
      _ds.putAll<T>(models);
  Author putAuthor({required String name}) => _ds.put(Author(name: name));
  Book putBook({required String title, required Author author}) =>
      _ds.put(Book(title: title, author: author));
  T remove<T extends MainModel>(T model) => _ds.remove<T>(model);
  List<T> removeAll<T extends MainModel>(Iterable<T> models) =>
      _ds.removeAll<T>(models);
  Stream<Author?> streamAuthor(ObjectId id) => _ds.stream<Author>(id);
  Stream<Book?> streamBook(ObjectId id) => _ds.stream<Book>(id);
  Stream<DataModelEvent<Author>> streamAuthors(
          {bool Function(Author model)? where}) =>
      _ds.streamAll<Author>(where: where);
  Stream<DataModelEvent<Book>> streamBooks(
          {bool Function(Book model)? where}) =>
      _ds.streamAll<Book>(where: where);
}

abstract class MainModel extends DataModel {
  MainModel([Map<String, dynamic>? fields]) : super(fields);
  MainModel.copyNew(MainModel original, Map<String, dynamic>? fields)
      : super.copyNew(original, fields);
  MainModel.copyWith(MainModel original, Map<String, dynamic>? fields)
      : super.copyWith(original, fields);
  MainModel.fromJson(
      data, Set<String> fields, Set<String> modelFields, bool newId)
      : super.fromJson(data, fields, modelFields, newId);
}

class Author extends MainModel {
  ObjectId get id => this['_modelId'];
  String get name => this['name'];

  Author({required String name}) : super({'name': name});

  Author.copyNew(Author original, {String? name})
      : super.copyNew(original, {'name': name});

  Author.copyWith(Author original, {String? name})
      : super.copyWith(original, {'name': name});

  Author.fromJson(data, {bool newId = false})
      : super.fromJson(data, {'name'}, {}, newId);

  Author copyNew({String? name}) => Author.copyNew(this, name: name);

  Author copyWith({String? name}) => Author.copyWith(this, name: name);
}

class Book extends MainModel {
  ObjectId get id => this['_modelId'];
  String get title => this['title'];
  Author get author => this['author'];

  Book({required String title, required Author author})
      : super({'title': title, 'author': author});

  Book.copyNew(Book original, {String? title, Author? author})
      : super.copyNew(original, {'title': title, 'author': author});

  Book.copyWith(Book original, {String? title, Author? author})
      : super.copyWith(original, {'title': title, 'author': author});

  Book.fromJson(data, {bool newId = false})
      : super.fromJson(data, {'title'}, {'author'}, newId);

  Book copyNew({String? title, Author? author}) =>
      Book.copyNew(this, title: title, author: author);

  Book copyWith({String? title, Author? author}) =>
      Book.copyWith(this, title: title, author: author);
}
