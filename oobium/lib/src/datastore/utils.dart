/// Pulled from dart:ui, so it can be used here without Flutter.
/// Jenkins hash function, optimized for small integers.
//
// Borrowed from the dart sdk: sdk/lib/math/jenkins_smi_hash.dart.
int combine(int hash, Object? o) {
  assert(o is! Iterable);
  hash = 0x1fffffff & (hash + o.hashCode);
  hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
  return hash ^ (hash >> 6);
}
int finish(int hash) {
  hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
  hash = hash ^ (hash >> 11);
  return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
}
