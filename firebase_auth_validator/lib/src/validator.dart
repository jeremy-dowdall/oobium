import 'dart:async';
import 'dart:io';
import 'dart:convert' as convert;

import 'package:firebase_auth_validator/src/firebase_token.dart';
import 'package:firebase_auth_validator/src/key_cache.dart';
import 'package:http/http.dart' as http;
import 'package:oobium_server/oobium_server.dart';

class FirebaseAuthValidator extends AuthValidator {

  final FutureOr<FirebaseToken> Function(String projectId, String token)? _decoder;

  FirebaseAuthValidator() :
    _decoder = null
  ;
  FirebaseAuthValidator.values({
    FutureOr<FirebaseToken> Function(String projectId, String token)? decoder,
    required AuthService service
  }) : _decoder = decoder, super.values(service: service);

  @override
  void onStop() {
    KeyCache.expire();
  }

  @override
  Future<bool> validate(Request req) async {
    final projectId = _getProjectId(req.host);
    final authHeader = req.headers[HttpHeaders.authorizationHeader];
    if(projectId is String && authHeader?.startsWith('Token ') == true) {
      final fireToken = await _decodeToken(projectId, authHeader!.split(' ')[1]);
      if(fireToken?.isValid() == true) {
        print('user: ${fireToken?.name} - ${fireToken?.email} (${fireToken?.uid})');
        final link = getLink((l) => l.type == 'firebase' && l.data == fireToken);
        if(link == null) {
          final link = putLink(type: 'firebase', code: fireToken!.uid!, data: fireToken.data.map((e,v) => MapEntry(e.toString(), v.toString())));
          req['uid'] = link.user.id;
        } else {
          updateUserToken(link.user.id);
          req['uid'] = link.user.id;
        }
        return true;
      } else {
        print('invalid fireToken: ${fireToken?.errors.join('\n')}');
      }
    }
    return false;
  }

  Future<FirebaseToken?> _decodeToken(String projectId, String token) async {
    try {
      if(_decoder != null) {
        return _decoder!(projectId, token);
      } else {
        return FirebaseToken.decode(
            projectId: projectId,
            token: token,
            publicKeys: await _fetchKeys()
        );
      }
    } catch(e) {
      print(e);
      return null;
    }
  }

  Future<Map<String, String>> _fetchKeys() async {
    final keyCache = KeyCache();
    if(keyCache.isExpired) {
      final uri = Uri.parse('https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com');
      final response = await http.get(uri);
      if(response.statusCode == 200) {
        final data = convert.jsonDecode(response.body) as Map;
        final expires = response.headers[HttpHeaders.expiresHeader];
        keyCache.setKeys(data, expires);
      }
    }
    return keyCache.keys;
  }

  dynamic _getProjectId(Host host) => (host.settings['firebase'] is Map) ? host.settings['firebase']['projectId'] : null;
}
