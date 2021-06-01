import 'dart:io' hide Link;

import 'package:firebase_auth_validator/firebase_auth_validator.dart';
import 'package:firebase_auth_validator/src/firebase_token.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:oobium_server/oobium_server.dart';
import 'package:test/test.dart';

import 'firebase_auth_validator_test.mocks.dart';

@GenerateMocks([AuthService])
void main() {

  group('firebase auth validator', () {
    test('valid', () async {
      Link? newLink;

      final service = MockAuthService();
      when(service.getLinks()).thenReturn([]);
      when(service.putLink(any)).thenAnswer((inv) => newLink = inv.positionalArguments[0] as Link);

      final decoder = (projectId, token) {
        expect(projectId, 'test-project');
        expect(token, 'TODO_TOKEN');
        return FirebaseToken(uid: 'FIRE_ID');
      };

      final validator = FirebaseAuthValidator.values(service: service, decoder: decoder);

      final req = Request.values(
          host: Server(settings: ServerSettings(custom: {'firebase': {'projectId': 'test-project'}})).host(),
          headers: RequestHeaders.values({HttpHeaders.authorizationHeader: 'Token TODO_TOKEN'})
      );

      final valid = await validator.validate(req);

      expect(valid, isTrue);
      expect(req.params['uid'], newLink?.user.id);
    });
  });
}
