import 'dart:async';

class Executor {

  Future<void>? _last;
  bool _canceled = false;
  bool get isCanceled => _canceled;
  bool get isNotCanceled => !isCanceled;

  Future<void> add(FutureOr Function(Executor e) op) => _add(op);
  
  Future<void> flush() => _last ?? Future.value();

  Future<void> cancel()  {
    _canceled = true;
    return _last ?? Future.value();
  }

  Future<void> _add(FutureOr Function(Executor e) op) async {
    if(isCanceled) {
      return;
    }
    
    final prev = _last;
    final completer = Completer.sync();
    _last = completer.future;
    if(prev != null) {
      await prev;
    }

    if(isNotCanceled) {
      await op(this);
    }

    if(identical(_last, completer.future)) {
      _last = null;
    }
    completer.complete();
  }
}
