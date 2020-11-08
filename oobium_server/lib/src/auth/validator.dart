import 'dart:io';
import 'dart:convert' as convert;

import 'package:http/http.dart' as http;

import 'firebase_token.dart';
import 'key_cache.dart';

class Validator {

  final String projectId;
  final keyCache = KeyCache();

  static final Map<String, Validator> _instances = {};
  factory Validator(String projectId) => _instances.putIfAbsent(projectId, () => Validator._(projectId));
  Validator._(this.projectId);

  void destroy() => _instances.remove(projectId);

  Future<bool> validate(String authorizationHeader) async {
    if(authorizationHeader == null || !authorizationHeader.startsWith('Token ')) {
      return false;
    }
    final fireToken = FirebaseToken.decode(
        token: authorizationHeader.split(' ')[1],
        projectId: projectId,
        publicKeys: await _fetchKeys()
    );
    if(fireToken.isValid()) {
      print('user: ${fireToken.name} - ${fireToken.email} (${fireToken.uid})');
      return true;
    } else {
      print('invalid fireToken: ${fireToken.errors.join('\n')}');
      return false;
    }
  }

  Future<Map<String, String>> _fetchKeys() async {
    if(keyCache.isExpired) {
      final url = 'https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com';
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = convert.jsonDecode(response.body) as Map;
        final expires = response.headers[HttpHeaders.expiresHeader];
        keyCache.setKeys(data, expires);
      }
    }
    return keyCache.keys;
  }
}