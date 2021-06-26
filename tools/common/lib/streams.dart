import 'dart:async';

class Streams<T> {
  final _streams = <Stream<T>>[];
  final _subs = <Stream<T>, StreamSubscription<T>>{};
  final _controller = StreamController<T>();
  final bool _autoClose;

  Streams([List<Stream<T>>? streams]) : _autoClose = streams != null {
    if(streams != null) {
      for(final stream in streams) {
        add(stream);
      }
    }
  }

  void add(Stream<T> stream) {
    _streams.add(stream);
    _subs[stream] = stream.listen(
        (e) => _controller.add(e),
        onError: (err) => remove(stream),
        onDone: () => remove(stream)
    );
  }

  Future<void> remove(Stream<T> stream) async {
    await _subs.remove(stream)?.cancel();
    if(_autoClose && _subs.isEmpty && !_controller.isClosed) {
      await _controller.close();
    }
  }

  Future<void> close() => Future.forEach<Stream<T>>(_streams.toList(), (stream) => remove(stream));

  Stream<T> get all => _controller.stream;
}