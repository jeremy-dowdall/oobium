import 'dart:io';

import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:oobium_connect/src/services/auth/validators.dart';
import 'package:oobium_connect/src/services/auth_service.dart';
import 'package:oobium_server/oobium_server.dart';
import 'package:test/test.dart';

import 'auth_service_test.mocks.dart';

T hostShim<T extends Service>() {
  throw 'not implemented';
}

@GenerateMocks([AuthService, WsProxy], customMocks: [
  MockSpec<Host>(fallbackGenerators: {#getService: hostShim})
])
void main() {

  group('test validator', () {
    test('valid', () async {
      final req = Request(
        host: Server(address: '127.0.0.1').host(),
        headers: RequestHeaders.values({HttpHeaders.authorizationHeader: 'Test SOME_TOKEN'})
      );

      final valid = await TestValidator().validate(req);

      expect(valid, isTrue);
      expect(req.params['uid'], 'SOME_TOKEN');
    });

    test('invalid: missing authorizationHeader', () async {
      final req = Request(
        host: Server(address: '127.0.0.1').host(),
        headers: RequestHeaders.values({HttpHeaders.authorizationHeader: 'todo'})
      );

      final valid = await TestValidator().validate(req);

      expect(valid, isFalse);
    });
    test('invalid: empty authorizationHeader', () async {
      final req = Request(
        host: Server(address: '127.0.0.1').host(),
        headers: RequestHeaders.values({HttpHeaders.authorizationHeader: ''})
      );

      final valid = await TestValidator().validate(req);

      expect(valid, isFalse);
    });
    test('invalid: bad authorizationHeader format', () async {
      final req = Request(
        host: Server(address: '127.0.0.1').host(),
        headers: RequestHeaders.values({HttpHeaders.authorizationHeader: 'invalid'})
      );

      final valid = await TestValidator().validate(req);

      expect(valid, isFalse);
    });
  });

  group('auth socket validator', () {
    group('new user', () {
      test('valid', () async {
        final code = 'single_use_code';

        final existingUser = User(name: 'joe');
        final service = MockAuthService();
        when(service.consume(code)).thenReturn(Token(user: existingUser));

        late User newUser;
        when(service.putUser(any)).thenAnswer((inv) => newUser = inv.positionalArguments[0] as User);

        final host = MockHost();
        final proxy = MockWsProxy();
        when(host.socket('${existingUser.id}')).thenReturn(proxy);
        when(proxy.getAny('/installs/approval')).thenAnswer((_) => Future.value(WsResult(200, true)));

        final req = Request(
          host: host,
          headers: RequestHeaders.values({WsProtocolHeader: '$WsAuthProtocol, $code'})
        );

        final valid = await AuthSocketValidator.values(service: service).validate(req);

        expect(valid, isTrue);
        expect(req.params['uid'], newUser.id);
      });
    });
    group('existing user', () {
      test('valid', () async {
        final service = MockAuthService();
        when(service.getUserToken('user_id')).thenReturn('token_id');

        final req = Request(
          host: MockHost(),
          headers: RequestHeaders.values({WsProtocolHeader: '$WsAuthProtocol, user_id-token_id'})
        );

        final valid = await AuthSocketValidator.values(service: service).validate(req);

        expect(valid, isTrue);
        expect(req.params['uid'], 'user_id');
      });
    });
  });
}

