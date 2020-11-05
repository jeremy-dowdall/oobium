import 'dart:async';

import 'package:oobium_client/src/auth.dart';
import 'package:oobium_client/src/models.dart';
import 'package:oobium_common/oobium_common.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Preferences {

  static init() async {
    _sharedPreferences = await SharedPreferences.getInstance();
  }
  static SharedPreferences _sharedPreferences;
  static SharedPreferences get _data {
    assert(_sharedPreferences != null, 'Local Storage has not been initialized. Call Preferences.init().');
    return _sharedPreferences;
  }
  
  final Auth auth;
  Preferences(this.auth) {
    auth.addListener(() { if(auth.user == null) dispose(); });
  }

  List<DisposableField> _fields;
  List<DisposableField> get fields => _fields;
  set fields(List<DisposableField> value) => _fields = (value != null) ? List.unmodifiable(value) : null;

  bool get isSetup => fields != null;
  bool get isNotSetup => !isSetup;
  
  void dispose() {
    _fields?.forEach((f) => f.dispose());
    _fields = null;
  }
}

class MultiField {
  StreamController _controller;
  MultiField(List<ReadableField> fields) : _controller = StreamController.broadcast() {
    Future.forEach(fields.toList(), (field) => _controller.addStream(field.stream));
  }
  Stream get stream => _controller.stream;
  dispose() {
    _controller.close();
  }
}

abstract class DisposableField {
  bool get isDisposed;
  void dispose();
}
abstract class ReadableField<T> extends DisposableField {
  T get value;
  Stream<T> get stream;
}
abstract class WritableField<T> extends ReadableField<T> {
  set value(T newValue);
}

class CacheField<T> extends WritableField<T> {
  T _value;
  T get value => _value;
  set value(T newValue) {
    _value = newValue;
    _controller.add(_value);
  }

  StreamController<T> _controller = StreamController<T>.broadcast();
  Stream<T> get stream => _controller.stream;

  bool _disposed;
  bool get isDisposed => _disposed;
  void dispose() {
    _disposed = true;
    _controller.close();
  }
}

class LocalField<T> extends WritableField<T> {

  final String name;
  final ModelContext context;
  LocalField(this.context, this.name) { load(); }

  T _value;
  T get value => _value;
  set value(T newValue) {
    _value = newValue;
    if(_value == null) Preferences._data.remove(name);
    else Preferences._data.setString(name, Json.encode(_value));
    _controller.add(_value);
  }

  StreamController<T> _controller = StreamController<T>.broadcast();
  Stream<T> get stream => _controller.stream;

  void load() {
    final json = Preferences._data.getString(name);
    final data = (json != null) ? Json.decode(json) : null;
    value = _build(data);
  }

  T _build(data) => context.build(data);

  bool _disposed;
  bool get isDisposed => _disposed;
  void dispose() {
    _disposed = true;
    _controller.close();
  }
}

class LocalFieldList<T> extends LocalField<List<T>> {

  LocalFieldList(ModelContext context, String name) : super(context, name);

  List<T> _build(data) {
    if(data is List) {
      return data.map((e) => context.build<T>(e)).toList();
    }
    return List<T>();
  }
}

class ModelField<T extends Model> extends CacheField<T> {

  final ModelContext context;
  final bool resolve;
  ModelField(this.context, {this.resolve = true, bool Function(T value, T model) select}) {
    context.observe<T>(all: (model) {
      if(select(value, model)) _setValue(model);
    });
  }

  Completer<T> _resolving;
  Future<T> get resolved => _resolving?.future ?? Future<T>.value(value);

  @override
  set value(T newValue) {
    if(newValue == null) value?.delete();
    else if(newValue.isNotSameAs(value)) newValue.save();
    _setValue(newValue);
  }

  _setResolvable(Resolvable<T> resolvable) {
    if(resolvable.isResolved) {
      super.value = resolvable as T;
    } else {
      _resolving ??= Completer<T>();
      resolvable.resolved().then((value) {
        super.value = value;
        _resolving.complete(value);
        _resolving = null;
      });
    }
  }

  _setValue(T newValue) {
    if(newValue is Resolvable) {
      _setResolvable(newValue as Resolvable);
    } else {
      super.value = newValue;
    }
  }

  @override
  void dispose() {
    context.removeObservers<T>();
    super.dispose();
  }
}

class ProxyField<F, T> implements WritableField<T> {

  final WritableField<F> _field;
  final T Function(F value) getter;
  final F Function(F fieldValue, T newValue) setter;
  ProxyField(this._field, {this.getter, this.setter});

  @override
  T get value => getter(_field.value);
  set value(T newValue) => _field.value = setter(_field.value, newValue);

  @override
  Stream<T> get stream => _field.stream.map((e) => getter(e));

  @override bool get isDisposed => _field.isDisposed;

  @override
  void dispose() {
    // nothing to do
  }
}

class CloudField<T> implements ReadableField<T> {

  final Future<T> Function() loader;
  final String name;
  final T Function(dynamic data) builder;
  final ModelContext context;
  CloudField({this.loader}) : name = null, builder = null, context = null { load(); }
  CloudField.local(this.context, this.name, {this.loader, this.builder}) { load(); }

  bool get isPersisted => name.isNotEmpty;
  bool get isNotPersisted => !isPersisted;

  T _value;
  T get value => _value;

  StreamController<T> _controller = StreamController<T>.broadcast();
  Stream<T> get stream => _controller.stream;

  bool _disposed;
  bool get isDisposed => _disposed;
  void dispose() {
    _disposed = true;
    _controller.close();
  }

  T build(data) {
    if(builder != null) return builder(data);
    if(context != null) return context.build<T>(data);
    return null;
  }

  Completer<T> _loading;
  void load() {
    if(_value == null && isPersisted) {
      final json = Preferences._data.getString(name);
      _value = build((json != null) ? Json.decode(json) : null);
      _controller.add(_value);
    }

    _loading ??= Completer<T>();
    loader().then((value) {
      _value = value;
      if(isPersisted) {
        if(_value == null) Preferences._data.remove(name);
        else Preferences._data.setString(name, Json.encode(_value));
      }
      _controller.add(_value);
      _loading.complete(_value);
      _loading = null;
    });
  }

  Future<T> loaded() async => _loading?.future ?? Future<T>.value(value);
}

class CloudFieldList<T> extends CloudField<List<T>> {

  CloudFieldList({Future<List<T>> loader()}) : super(loader: loader);
  CloudFieldList.local(ModelContext context, String name, {Future<List<T>> loader(), List<T> builder(data)}) :
    super.local(context, name, loader: loader, builder: builder);

  List<T> build(data) {
    if(data is List) {
      if(builder != null) return builder(data);
      if(context != null) return data.map((e) => context.build<T>(e)).toList();
    }
    return List<T>();
  }
}
