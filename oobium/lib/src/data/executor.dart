import 'dart:async';

class Executor {

  bool _canceled = false;
  Future<void> _last;

  Future<void> add(FutureOr Function() op) => _add(op);
  
  Future<void> flush() => close(cancel: false);

  Future<void> close({bool cancel = false}) {
    _canceled = cancel ?? false;
    return _last ?? Future.value();
  }

  Future<void> _add(FutureOr Function() op) async {
    if(_canceled) {
      return;
    }
    
    final prev = _last;
    final completer = Completer.sync();
    _last = completer.future;
    if(prev != null) {
      await prev;
    }

    if(!_canceled) {
      await op();
    }

    if(identical(_last, completer.future)) {
      _last = null;
    }
    completer.complete();
  }
}
