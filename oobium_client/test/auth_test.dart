import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:oobium_client/oobium_client.dart';
import 'package:oobium_client/src/models.dart';
import 'package:oobium/oobium.dart';

class TestAuthenticator extends Mock implements Authenticator { }
class TestPersistor extends Mock implements Persistor { }
class TestUser extends Model<TestUser, TestUser> {
  TestUser(ModelContext context, String id, Link owner, Access access) : super(context, id, owner, access);
  TestUser.fromJson(ModelContext context, data) : super.fromJson(context, data);
  @override copyWith({String id, Link owner, Access access}) => throw UnimplementedError();
}

void main() {
  group('test authId', () {
    test('test that Models.authId is set when Auth user is set', () async {
      final auth = ClientAuth(TestAuthenticator());
      final context = ModelContext(auth);

      auth.setAuthUser(AuthUser(id: 'test-uid-01', name: 'Test User'));

      expect(context.uid, 'test-uid-01');
    });
  });

  group('test sign in', () {
    TestAuthenticator authenticator;
    setUp(() async {
      authenticator = TestAuthenticator();
      when(authenticator.getCurrentUser()).thenAnswer((_) async => AuthUser());
    });

    test('test failed signin: email=null and password=null', () async {
      final state = ClientAuth(authenticator);

      final result = await state.signInOrCreate(email: null, password: null);

      expect(result.failure, isTrue);
      expect(result.error, isNotNull);
      expect(result.error.message, AuthError.EmailInvalid.message);
      verifyNever(authenticator.signInWithEmailAndPassword(any, any));
      verifyNever(authenticator.createUserWithEmailAndPassword(any, any));
    });

    test('test failed signin: email="notnull" and password=null', () async {
      final state = ClientAuth(authenticator);

      final result = await state.signInOrCreate(email: 'notnull', password: null);

      expect(result.failure, isTrue);
      expect(result.error, isNotNull);
      expect(result.error.message, AuthError.PasswordInvalid.message);
      verifyNever(authenticator.signInWithEmailAndPassword(any, any));
      verifyNever(authenticator.createUserWithEmailAndPassword(any, any));
    });

    test('test failed signin: email="found" and password="incorrect"', () async {
      final error = AuthError.PasswordIncorrect;
      final state = ClientAuth(authenticator);
      when(authenticator.signInWithEmailAndPassword('found', 'incorrect')).thenThrow(PlatformException(code: error.code));

      final result = await state.signInOrCreate(email: 'found', password: 'incorrect');

      expect(result.failure, isTrue);
      expect(result.error, isNotNull);
      expect(result.error.message, error.message);
      verify(authenticator.signInWithEmailAndPassword(any, any)).called(1);
      verifyNever(authenticator.createUserWithEmailAndPassword(any, any));
    });

    test('test failed signin: email="disabled" and password="correct"', () async {
      final error = AuthError.AccountDisabled;
      final state = ClientAuth(authenticator);
      when(authenticator.signInWithEmailAndPassword('disabled', 'correct')).thenThrow(PlatformException(code: error.code));

      final result = await state.signInOrCreate(email: 'disabled', password: 'correct');

      expect(result.failure, isTrue);
      expect(result.error, isNotNull);
      expect(result.error.message, error.message);
      verify(authenticator.signInWithEmailAndPassword(any, any)).called(1);
      verifyNever(authenticator.createUserWithEmailAndPassword(any, any));
    });

    test('test successful signin: email="found" and password="correct"', () async {
      final state = ClientAuth(authenticator);
      when(authenticator.signInWithEmailAndPassword('found', 'correct')).thenAnswer((_) async => AuthResult.success(AuthUser(id: 'found')));

      final result = await state.signInOrCreate(email: 'found', password: 'correct');

      expect(result.success, isTrue);
      expect(result.user, isNotNull);
      expect(result.user.id, 'found');
      verify(authenticator.signInWithEmailAndPassword(any, any)).called(1);
      verifyNever(authenticator.createUserWithEmailAndPassword(any, any));

      expect(state.user, result.user);
      expect(state.uid, result.user.id);
    });

    test('test successful create account: email="notfound" and password="valid"', () async {
      final state = ClientAuth(authenticator);
      when(authenticator.signInWithEmailAndPassword('notfound', 'valid')).thenThrow(PlatformException(code: AuthError.AccountNotFound.code));
      when(authenticator.createUserWithEmailAndPassword('notfound', 'valid')).thenAnswer((_) async => AuthResult.success(AuthUser(id: 'notfound')));

      final result = await state.signInOrCreate(email: 'notfound', password: 'valid');

      expect(result.success, isTrue);
      expect(result.user, isNotNull);
      expect(result.user.id, 'notfound');
      verify(authenticator.signInWithEmailAndPassword(any, any)).called(1);
      verify(authenticator.createUserWithEmailAndPassword(any, any)).called(1);
    });
  });
}