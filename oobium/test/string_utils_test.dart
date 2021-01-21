import 'package:oobium_test/oobium_test.dart';
import 'package:test/test.dart';
import 'package:oobium/src/router.extensions.dart';

void main() {
  group('test verifiedSegments', () {
    test('<test>', () {
      final s = '<test>';
      final segments = s.verifiedSegments;
      expect(segments.length, 1);
      expect(segments[0], '<test>');
    });
    test('<test1><test2>', () {
      final s = '<test1><test2>';
      expectError(() => s.verifiedSegments, 'contiguous variables are not permitted: \'$s\'');
    });
    test('/path/<>', () {
      final s = '/path/<>';
      expectError(() => s.verifiedSegments, 'empty variable segments are not permitted: \'$s\'');
    });
    test('/path/<test>', () {
      final s = '/path/<test>';
      final segments = s.verifiedSegments;
      expect(segments.length, 2);
      expect(segments[0], 'path');
      expect(segments[1], '<test>');
    });
  });
  group('test findRouterPath', () {
    test('/path -> /path', () {
      expect('/path'.findRouterPath(['/not','/path']), '/path');
    });
    test('/path/val -> /path/<var>', () {
      expect('/path/val'.findRouterPath(['/path/<var>']), '/path/<var>');
    });
    test('/path/valley -> /path/<var> !/path/<var>ley', () {
      expect('/path/valley'.findRouterPath(['/path/<var>', '/path/<var>ley']), '/path/<var>');
    });
    test('/path/val/not -> /path/<var>/not !/path/<var>', () {
      expect('/path/val/not'.findRouterPath(['/path/<var>', '/path/<var>/not']), '/path/<var>/not');
    });
  });
  group('test parseData', () {
    test('/path + /path = {}', () {
      expect('/path'.parseParams('/path'), {});
    });
    test('/path/val + /path/<var> -> {var: val}', () {
      expect('/path/val'.parseParams('/path/<var>'), {'var': 'val'});
    });
    test('/path/valley + /path/<var>ley -> {var: val}', () {
      expect('/path/val'.parseParams('/path/<var>'), {'var': 'val'});
    });
  });
}