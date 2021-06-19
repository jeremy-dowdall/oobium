import 'dart:async';

class CancelableCompleter<T> {

  T? _value;
  var _completed = false;
  final _futures = <CancelableFuture>[];

  CancelableFuture get future {
    final future = CancelableFuture<T>(this);
    if(_completed) {
      future._complete(_value);
    } else {
      _futures.add(future);
    }
    return future;
  }

  void complete([FutureOr<T>? value]) {
    Future.value(value).then((value) {
      _completed = true;
      _value = value;
      for(final future in _futures.toList()) {
        future._complete(value);
      }
    });
  }

  bool get isCompleted => _completed;
  bool get isNotCompleted => !isCompleted;
}

class CancelableFuture<T> implements Future<T?> {

  CancelableCompleter<T> _parent;
  final _completer = Completer<T?>();

  CancelableFuture(this._parent);

  void _complete([T? value]) {
    _parent._futures.remove(this);
    _completer.complete(value);
  }

  void cancel([T? value]) {
    _parent._futures.remove(this);
    _completer.complete(value);
  }

  @override
  Stream<T?> asStream() {
    return _completer.future.asStream();
  }

  @override
  Future<T?> catchError(Function onError, {bool Function(Object error)? test}) {
    return _completer.future.catchError(onError, test: test);
  }

  @override
  Future<R> then<R>(FutureOr<R> Function(T? value) onValue, { Function? onError }) {
    return _completer.future.then<R>(onValue, onError: onError);
  }

  @override
  Future<T?> timeout(Duration timeLimit, {FutureOr<T?> Function()? onTimeout}) {
    return _completer.future.timeout(timeLimit, onTimeout: onTimeout);
  }

  @override
  Future<T?> whenComplete(FutureOr<void> Function() action) {
    return _completer.future.whenComplete(action);
  }
}
