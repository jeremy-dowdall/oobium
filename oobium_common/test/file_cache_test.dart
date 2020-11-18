import 'package:oobium_common/src/file_cache.dart';
import 'package:test/test.dart';

Future<void> main() async {
  final cache = await FileCache('test-cache')..init();
  setUp(() async => await cache.reset());
  tearDownAll(() async => await cache.destroy());

  test('test put', () async {
    await cache.put('test-key', 'test-data');
    expect(await cache.get('test-key'), 'test-data');
  });

  test('test loadSync', () async {
    await cache.put('test-key', 'test-data');
    final size = cache.size;
    await cache.load();
    expect(await cache.get('test-key'), 'test-data');
    expect(cache.size, size);
  });

  test('test nonexistent key is expired', () async {
    expect(cache.isExpired('any-key'), true);
  });

  test('test cache isExpired is false', () async {
    await cache.put('test-key', 'test-data');
    expect(cache.isExpired('test-key'), false);
  });

  test('test cache isExpired is true', () async {
    await cache.put('test-key', 'test-data', expiresAt: DateTime.now().subtract(Duration(milliseconds: 1)));
    expect(cache.isExpired('test-key'), true);
  });

  test('test size', () async {
    await cache.put('test-key-1', 'test-data');
    expect(cache.size, 18+9);
    await cache.put('test-key-1', 'test-data-2');
    expect(cache.size, 18+11);
    await cache.put('test-key-2', 'test-data-3');
    expect(cache.size, 18+11+18+11);
    await cache.put('test-key-1', null);
    expect(cache.size, 18+11);
  });
}
