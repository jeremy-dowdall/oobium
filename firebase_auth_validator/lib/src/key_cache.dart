import 'package:http_parser/http_parser.dart';

class KeyCache {

  static final _instance = KeyCache._();
  factory KeyCache() => _instance;
  KeyCache._();

  Map<String, String>? _keys;
  Map<String, String> get keys => _keys ?? {};

  DateTime? _expiresAt;
  bool get isExpired => _expiresAt == null || _expiresAt!.isBefore(DateTime.now());

  void setKeys(Map? data, String? expires) {
    _keys = data?.map((k,v) => MapEntry(k.toString(), v.toString())) ?? {};
    _expiresAt = (expires != null) ? parseHttpDate(expires) : null;
  }

  static void expire() {
    _instance._keys?.clear();
    _instance._keys = null;
    _instance._expiresAt = null;
  }
}
