import 'package:oobium_websocket/src/cancelable_completer.dart';
import 'package:test/test.dart';

void main() {
  group('then', () {
    test('void', () async {
      final completer = CancelableCompleter();
      completer.future.then(expectAsync1((_) {}, count: 1));
      completer.complete();
    });

    test('String', () async {
      final completer = CancelableCompleter<String>();
      completer.future.then(expectAsync1((value) {
        expect(value, 'test');
      }, count: 1));
      completer.complete('test');
    });

    test('2 futures', () async {
      final completer = CancelableCompleter<String>();
      final future1 = completer.future;
      final future2 = completer.future;

      future1.then(expectAsync1((value) {
        expect(value, 'test');
      }, count: 1));
      future2.then(expectAsync1((value) {
        expect(value, 'test');
      }, count: 1));

      completer.complete('test');
    });

    test('2 futures, 1 canceled', () async {
      final completer = CancelableCompleter<String>();
      final future1 = completer.future;
      final future2 = completer.future;

      future1.then(expectAsync1((value) {
        expect(value, isNull);
      }, count: 1));
      future2.then(expectAsync1((value) {
        expect(value, 'test');
      }, count: 1));

      future1.cancel();
      completer.complete('test');
    });
  });

  group('await', () {
    test('String', () async {
      final completer = CancelableCompleter<String>();
      Future.delayed(Duration(milliseconds: 10), () => completer.complete('test'));
      expect(await completer.future, 'test');
    });

    test('String, already completed', () async {
      final completer = CancelableCompleter<String>();
      completer.complete('test');
      expect(await completer.future, 'test');
    });

    test('String, canceled', () async {
      final completer = CancelableCompleter<String>();
      final future = completer.future;
      Future.delayed(Duration(milliseconds: 10), () => future.cancel());
      expect(await future, isNull);
    });

    test('2 futures', () async {
      final completer = CancelableCompleter<String>();
      final future1 = completer.future;
      final future2 = completer.future;
      Future.delayed(Duration(milliseconds: 10), () {
        completer.complete('test');
      });
      expect(await future1, 'test');
      expect(await future2, 'test');
    });

    test('2 futures, 1 canceled', () async {
      final completer = CancelableCompleter<String>();
      final future1 = completer.future;
      final future2 = completer.future;
      Future.delayed(Duration(milliseconds: 10), () {
        future1.cancel();
        completer.complete('test');
      });
      expect(await future1, isNull);
      expect(await future2, 'test');
    });
  });
}