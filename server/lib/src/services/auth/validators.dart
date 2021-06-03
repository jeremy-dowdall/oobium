import 'dart:io' show HttpHeaders;

import 'package:oobium_server/src/services/auth_service.dart';
import 'package:oobium_server/src/server.dart';

class AuthSocketValidator extends AuthValidator {

  AuthSocketValidator();
  AuthSocketValidator.values({required AuthService service}) : super.values(service: service);

  @override
  Future<bool> validate(Request req) async {
    final authToken = _parseAuthToken(req);
    if(authToken is String) {
      if(authToken.contains('-')) {
        final sa = authToken.split('-');
        if(hasUser(sa[0], sa[1])) {
          req['uid'] = sa[0];
          return true;
        }
        print('auth failed with token: $authToken');
      } else {
        final token = consume(authToken);
        if(token != null && token.user != null) {
          final approval = await req.host.socket(token.user!.id).getAny('/installs/approval');
          if(approval.isSuccess == true && approval.data == true) {
            final user = putUser(token);
            req['uid'] = user.id;
            return true;
          } else {
            print('auth failed on approval of code: $authToken');
          }
        } else {
          print('auth failed with code: $authToken');
        }
      }
    }
    return false;
  }

  String? _parseAuthToken(Request req) {
    final protocols = req.headers[WsProtocolHeader]?.split(', ') ?? <String>[];
    if(protocols.length == 2 && protocols[0] == WsAuthProtocol) {
      return protocols[1];
    }
    return null;
  }
}

class RestValidator extends AuthValidator {
  @override
  Future<bool> validate(Request req) async {
    final authHeader = req.headers[HttpHeaders.authorizationHeader];
    if(authHeader is String && authHeader.contains('-')) {
      final sa = authHeader.split('-');
      if(hasUser(sa[0], sa[1])) {
        req['uid'] = sa[0];
        return true;
      }
      print('auth failed with header: $authHeader');
    }
    return false;
  }
}

class TestValidator extends AuthValidator {
  @override
  Future<bool> validate(Request req) async {
    final authHeader = req.headers[HttpHeaders.authorizationHeader] ?? '';
    if(authHeader.startsWith('Test ') && req.host.settings.address == '127.0.0.1') {
      req.params['uid'] = authHeader.split(' ')[1];
      return true;
    }
    return false;
  }
}
