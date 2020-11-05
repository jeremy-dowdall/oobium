import 'dart:async';

import 'package:oobium_client/src/auth.dart';
import 'package:oobium_common/oobium_common.dart';

abstract class Access implements JsonString {

  static final Map<Type, _AccessAttacher> _attachers = {};
  static final Map<String, Access Function(String ownerId, String value)> _builders = {};
  static void register<T extends Access>({
    Access Function(String ownerId, T access) attach,
    Access Function(String ownerId, String value) build,
  }) {
    _attachers[T] = _AccessAttacher<T>(attach);
    _builders[_key(T)] = build;
  }
  static String _key(Type t) {
    final type = t.toString();
    return '${type[0].toLowerCase()}${type.substring(1, type.length-6)}';
  }

  static Access attached(ModelContext context, String ownerId, Access access) {
    if(access == public) return access;

    final key = access?.runtimeType;
    final value = ownerId.orElse(context.uid);

    if(_attachers.containsKey(key)) return _attachers[key].attach(value, access);
    return PrivateAccess._(context, value);
  }

  static Access fromJson(ModelContext context, data, [field = 'access']) {
    final ownerId = Json.string(data, 'ownerId').orElse(context.uid);
    if(Json.has(data, field)) {
      final strings = Json.string(data, field).split(':');
      final key = strings[0];
      final value = (strings.length > 1) ? strings[1] : null;

      if(key == 'public') return public;
      if(_builders.containsKey(key)) return _builders[key](ownerId, value);
    }
    return PrivateAccess._(context, ownerId);
  }

  static final Access public = PublicAccess._();
  static final Access private = PrivateAccess._(null, null);

  bool get isGranted;
}
class _AccessAttacher<T> {
  final Access Function(String ownerId, T access) attach;
  _AccessAttacher(this.attach);
}
class PublicAccess extends Access {
  PublicAccess._();
  @override bool get isGranted => true;
  @override String toJsonString() => 'public';
  @override String toString() => 'Access.public';
}
class PrivateAccess extends Access {
  final ModelContext context;
  final String ownerId;
  PrivateAccess._(this.context, this.ownerId);
  @override bool get isGranted => ownerId == context?.uid;
  @override String toJsonString() => null;
  @override String toString() => 'Access.private($ownerId)';
}

abstract class Resolvable<T> {
  bool get isResolved;
  bool get isNotResolved;
  Future<T> resolved();
}

class Link<T> implements JsonString, Resolvable<Link<T>> {

  final ModelContext context;
  final String id;
  final T model;
  Link(this.context, {this.id, this.model});

  get type => T;

  Completer<T> _getting;

  Future<T> get({T orElse}) {
    if(model != null) return Future.value(model);
    if(_getting != null) return _getting.future;

    assert(id.isNotBlank, 'cannot load $T($id): id is blank');

    _getting ??= Completer<T>();
    context.get<T>(id, orElse: orElse).then((value) {
      _getting.complete(value);
      _getting = null;
    });
    return _getting.future;
  }

  Link<T> reset() => Link<T>(context, id: id);

  @override
  Future<Link<T>> resolved() async {
    return isResolved ? this : Link<T>(context, id: id, model: await get());
  }

  bool get isNull => id == null || id.isEmpty;
  bool get isNotNull => !isNull;
  @override bool get isResolved => (id == null) || (model != null);
  @override bool get isNotResolved => !isResolved;

  @override
  bool operator ==(Object other) => (other is Link) && id == other.id && type == other.type;

  @override
  int get hashCode => '$type:$id'.hashCode;

  @override
  String toJsonString() => id;

  @override
  String toString() => 'Link<$T>(id: $id)';
}

class ChildLink<T> implements JsonString, Resolvable<ChildLink<T>> {

  final ModelContext context;
  final String parentId;
  final String id;
  final T model;
  ChildLink(this.context, {this.parentId, this.id, this.model});

  get type => T;

  Future<T> get({T orElse}) async {
    if(model != null) return model;
    assert(id.isNotBlank && parentId.isNotBlank,
      'cannot load $T($parentId, $id): ${parentId.isBlank ? 'parentId is blank' : ''}${parentId.isBlank && id.isBlank ? ', ' : ''}${id.isBlank ? 'id is blank' : ''}'
    );
    return await context.get<T>('$parentId:$id', orElse: orElse);
  }

  @override
  Future<ChildLink<T>> resolved() async {
    return isResolved ? this : ChildLink<T>(context, id: id, parentId: parentId, model: await get());
  }

  bool get isNull => id == null || id.isEmpty;
  bool get isNotNull => !isNull;
  @override bool get isResolved => (parentId == null) || (id == null) || (model != null);
  @override bool get isNotResolved => !isResolved;

  @override
  bool operator ==(Object other) => (other is ChildLink) && type == other.type && parentId == other.parentId && id == other.id;

  @override
  int get hashCode => '$type:$parentId:$id'.hashCode;

  @override
  String toJsonString() => id;

  @override
  String toString() => 'ChildLink<$T>(parentId: $parentId, id: $id)';
}

class HasMany<T> implements Resolvable<HasMany<T>> {

  List<T> _models;
  HasMany([Iterable<T> models]) : _models = models?.toList();

  List<T> get models => (_models != null) ? List.unmodifiable(_models) : null;

  HasManyResolver<T> _resolver;
  set resolver(HasManyResolver<T> value) {
    if(_models != null) {
      _models = _models.map(value.linker).toList();
    } else {
      _resolver = value;
    }
  }

  @override bool get isResolved => _models != null;
  @override bool get isNotResolved => !isResolved;

  int get length => _models?.length ?? 0;
  T operator [](int index) => (index >= 0 && index < length) ? _models[index] : null;

  Type get type => T;
  String get ownerId => _resolver?.ownerId;
  String get field => _resolver?.field;
  String get id => _resolver?.id;

  @override
  Future<HasMany<T>> resolved({Future<T> Function(T) map}) async {
    if(isResolved) return this;
    return HasMany<T>(await _resolver.resolve(map));
  }

  @override
  String toString() => 'HasMany<$T>(resolver: $_resolver)';
}

class HasManyResolver<T> {
  final Model model;
  final String field;
  final T Function(T) linker;
  HasManyResolver(this.model, this.field, this.linker);

  Type get type => T;
  String get ownerId => model.owner?.id ?? model.context.uid;
  String get id => model.id;

  Future<Iterable<T>> resolve(Future<T> Function(T) map) async {
    Iterable<T> data = await model.context.getAll<T>([Where('ownerId', isEqualTo: ownerId), Where(field, isEqualTo: id)]);
    data = data.map(linker);
    if(map != null) data = (await Future.wait<T>(data.map(map)));
    return data;
  }

  @override
  String toString() => 'HasManyResolver<$T>($field == $id && ownerId == $ownerId)';
}

class Validation {
  final List<String> _errors;
  Validation([String error]) : _errors = (error != null) ? [error] : [];
  bool get isSuccess => _errors.isEmpty;
  bool get isFailure => !isSuccess;
  String get message => isFailure ? _errors?.join(',\n') : null;
}

class Where {
  final dynamic field;
  final dynamic isEqualTo;
  final dynamic isLessThan;
  final dynamic isLessThanOrEqualTo;
  final dynamic isGreaterThan;
  final dynamic isGreaterThanOrEqualTo;
  final dynamic arrayContains;
  final List<dynamic> arrayContainsAny;
  final List<dynamic> whereIn;
  final bool isNull;

  Where(this.field, {
    this.isEqualTo,
    this.isLessThan,
    this.isLessThanOrEqualTo,
    this.isGreaterThan,
    this.isGreaterThanOrEqualTo,
    this.arrayContains,
    this.arrayContainsAny,
    this.whereIn,
    this.isNull,
  });
}

class SaveResult {

  final Validation _validation;
  final List<Model> saves;
  SaveResult.success(this.saves) : _validation = null;
  SaveResult.failure(this._validation) : saves = null;

  bool get isSuccess => _validation == null;
  bool get isFailure => !isSuccess;

  String get message => _validation?.message;
}

abstract class ModelBuilder {
  Map<Type, Function(ModelContext context, Map data)> builders;
  Map<Type, Function(ModelContext context, List<Map> data)> listBuilders;
}

abstract class Persistor {
  Future<bool> any<T>(ModelContext context, Iterable<Where> conditions);
  Future<bool> exists<T>(ModelContext context, String id);
  Future<T> get<T>(ModelContext context, String id, {T orElse});
  Future<List<T>> getAll<T>(ModelContext context, Iterable<Where> conditions);
  Stream<T> stream<T>(ModelContext context, String id, {void onData(T event), Function onError, void onDone(), bool cancelOnError});
  Stream<List<T>> streamAll<T>(ModelContext context, Iterable<Where> conditions, {void onData(T event), Function onError, void onDone(), bool cancelOnError});
  String newId<T>(ModelContext context);
  Future<bool> delete(Model model, {Iterable inBatchWith});
  Future<SaveResult> save(Model model, {List<Model> inBatchWith, List<Model> andDelete});
}

class ModelContext {

  void dispose() {
    _builders.clear();
    _persistors.clear();
    _onGetObservers.clear();
    _onSaveObservers.clear();
    _onDeleteObservers.clear();
  }

  final Auth auth;
  ModelContext(this.auth);
  String get uid => auth.uid;
  AuthUser get authUser => auth.user;
  Future<String> getAuthToken() => auth.getAuthToken();
  Future<String> getIdToken() => auth.getIdToken();

  final Map<Type, Function(ModelContext context, Map data)> _builders = {};
  final Map<Type, Persistor> _persistors = {};

  void addBuilder<T>(T builder(ModelContext context, Map data)) {
    _builders[T] = builder;
  }
  void register<T>(Persistor persistor) {
    _persistors[T] = persistor;
  }

  T build<T>([Map data]) => _builderOf(T)(this, data);
  bool canBuild(Type type) => _builders[type] != null;
  bool cannotBuild(Type type) => !canBuild(type);
  bool canPersist(Type type) => _persistors[type] != null;
  bool cannotPersist(Type type) => !canPersist(type);

  Function(ModelContext context, Map data) _builderOf(Type type) {
    assert(canBuild(type), 'no builder registered for $type');
    return _builders[type];
  }

  Persistor _persistorOf(Type type) {
    assert(canPersist(type), 'no persistor registered for $type');
    return _persistors[type];
  }

  final Map<Type, Function> _onGetObservers = {};
  final Map<Type, Function> _onSaveObservers = {};
  final Map<Type, Function> _onDeleteObservers = {};
  void observe<T>({void all(T model), void onGet(T model), void onSave(T model), void onDelete(T model)}) {
    _onGetObservers[T] = onGet ?? all;
    _onSaveObservers[T] = onSave ?? all;
    _onDeleteObservers[T] = onDelete ?? all;
  }
  void removeObservers<T>() {
    _onGetObservers.remove(T);
    _onSaveObservers.remove(T);
    _onDeleteObservers.remove(T);
  }

  String newId<T>() => _persistorOf(T).newId<T>(this);
  Future<bool> any<T>(Iterable<Where> conditions) => _persistorOf(T).any<T>(this, conditions);
  Future<bool> exists<T>(String id) => _persistorOf(T).exists<T>(this, id);
  Future<List<T>> getAll<T>(Iterable<Where> conditions) => _persistorOf(T).getAll<T>(this, conditions);
  Stream<T> stream<T>(String id, {void onData(T event), Function onError, void onDone(), bool cancelOnError}) => _persistorOf(T).stream<T>(this, id, onData: onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  Stream<List<T>> streamAll<T>(Iterable<Where> conditions, {void onData(T event), Function onError, void onDone(), bool cancelOnError}) => _persistorOf(T).streamAll<T>(this, conditions, onData: onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError);

  Future<T> get<T>(String id, {T orElse}) async {
    final model = await _persistorOf(T).get<T>(this, id, orElse: orElse);
    if(model != null) {
      _onGetObservers[model.runtimeType]?.call(model);
    }
    return model;
  }

  Future<bool> delete(Model model, {Iterable inBatchWith}) async {
    final result = await _persistorOf(model.runtimeType).delete(model, inBatchWith: inBatchWith);
    if(result) {
      _onDeleteObservers[model.runtimeType]?.call(model);
    }
    return result;
  }

  Future<SaveResult> save(Model model, {List<Model> inBatchWith, List<Model> andDelete}) async {
    final result = await _persistorOf(model.runtimeType).save(model, inBatchWith: inBatchWith, andDelete: andDelete);
    if(result.isSuccess) {
      _onSaveObservers[model.runtimeType]?.call(result.saves[0]);
    }
    return result;
  }
}

abstract class Model<T, O> extends JsonModel {

  final ModelContext context;
  final Link<O> owner;
  final Access access;
  Model(this.context, String id, Link<O> owner, Access access) :
      this.owner = (owner?.isNotNull == true) ? owner : Link<O>(context, id: context.uid),
      this.access = Access.attached(context, owner?.id, access),
      super(id);
  Model.fromJson(ModelContext context, data) :
      this.context = context,
      owner = Json.field<Link<O>, String>(data, 'ownerId', (v) => Link<O>(context, id: v.orElse(context.uid))),
      access = Access.fromJson(context, data),
      super.fromJson(data)
  ;

  T copyWith({String id, Link<O> owner, Access access});

  bool get isNew => id == null || id.isEmpty;
  bool get isNotNew => !isNew;

  Link<T> _link;
  Link<T> get link => _link ??= Link<T>(context, id: id, model: this as T);

  bool isSameAs(other) => !isNotSameAs(other);
  bool isNotSameAs(other) {
    if(runtimeType == other?.runtimeType && id == other?.id) {
      final json1 = toJson(), json2 = other.toJson();
      return json1.keys.any((k) => json1[k] != json2[k]);
    }
    return true;
  }

  Future<bool> delete({Iterable inBatchWith}) => context.delete(this, inBatchWith: inBatchWith);
  Future<SaveResult> save({List<Model> inBatchWith, List<Model> andDelete}) => context.save(this, inBatchWith: inBatchWith, andDelete: andDelete);
  Validation validate([Validation validation]) {
    validation ??= Validation();
    validations(validation._errors);
    return validation;
  }

  /// subclasses to override if necessary
  void validations(List<String> errors) { }

  @override
  Map<String, dynamic> toJson() => super.toJson()
    ..['ownerId'] = Json.from(owner)
    ..['access'] = Json.from(access)
  ;
}

abstract class NullValue {
  static final dateTime = NullDateTime();
  static final iterable = NullIterable();
}
class NullDateTime extends DateTime implements NullValue { NullDateTime() : super(0); }
class NullIterable extends Iterable implements NullValue { NullIterable(); @override Iterator get iterator => throw UnimplementedError(); }

nullable(v1, v2) => (v1 is NullValue) ? null : (v1 ?? v2);