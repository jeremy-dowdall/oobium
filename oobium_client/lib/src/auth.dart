import 'dart:async';

import 'package:flutter/services.dart';
import 'package:oobium_common/oobium_common.dart';

abstract class AuthStateValue { }
class Anonymous extends AuthStateValue {}
class SigningIn extends AuthStateValue {}
class SettingUp extends AuthStateValue {}
class SignedIn extends AuthStateValue {}

class Auth {

  static List<AuthStateValue> get _defaultStates => <AuthStateValue>[
    Anonymous(), SigningIn(), SettingUp(), SignedIn()
  ];
  
  final Authenticator _authenticator;
  final List<AuthStateValue> _states;
  int statePosition = 0;
  StreamSubscription _authSubscription;
  Auth(Authenticator authenticator, {List<AuthStateValue> states}) :
    _authenticator = authenticator,
    _states = List<AuthStateValue>.unmodifiable(states ?? _defaultStates)
  {
    subscribe();
  }

  Type get state => (statePosition == -1) ? _states.last.runtimeType : _states[statePosition].runtimeType;
  set state(Type value) {
    statePosition = _states.indexWhere((e) => e.runtimeType == value);
    notifyListeners();
  }

  void subscribe() {
    _authSubscription?.cancel();
    _authSubscription = _authenticator.onAuthStateChanged?.listen((authUser) => setAuthUser(authUser));
  }
  void unsubscribe() {
    _authSubscription?.cancel();
  }

  List<Function> _authListeners = [];
  void addListener(listener()) {
    if(!_authListeners.contains(listener)) _authListeners.add(listener);
  }
  Future<void> notifyListeners() async {
    await Future.forEach(_authListeners.toList(), (f) => f());
  }
  void removeListener(listener) {
    _authListeners.remove(listener);
  }

  AuthUser _authUser;
  String get uid => _authUser?.uid;
  AuthUser get user => _authUser;
  AuthUser setAuthUser(AuthUser authUser) {
    _authUser = authUser ?? AuthUser();
    if(_authUser.isAnonymous) {
      state = Anonymous;
    } else {
      state = SettingUp;
    }
    return _authUser;
  }

  void dispose() {
    _authSubscription?.cancel();
    _authListeners.clear();
  }

  Future<AuthResult> signInOrCreate({String email, String password}) {
    if(email.isBlank) return Future.value(AuthResult.failure(AuthError.EmailInvalid));
    if(password.isBlank) return Future.value(AuthResult.failure(AuthError.PasswordInvalid));
    return _signIn(() async {
      try {
        return await signInWithEmailAndPassword(email, password);
      } on PlatformException catch(e) {
        if(e.code == AuthError.AccountNotFound.code) { // user does not exist, try creating
          try {
            return await createUserWithEmailAndPassword(email, password);
          } on PlatformException catch(e) {
            if(e.code == AuthError.EmailInUse.code)           return AuthResult.failure(AuthError.EmailInUse);
            else if(e.code == AuthError.EmailInvalid.code)    return AuthResult.failure(AuthError.EmailInvalid);
            else if(e.code == AuthError.PasswordInvalid.code) return AuthResult.failure(AuthError.PasswordInvalid);
            return AuthResult.failure(AuthError.Unknown);
          }
        }
        else if(e.code == AuthError.PasswordIncorrect.code) return AuthResult.failure(AuthError.PasswordIncorrect);
        else if(e.code == AuthError.EmailInvalid.code)      return AuthResult.failure(AuthError.EmailInvalid);
        else if(e.code == AuthError.AccountDisabled.code)   return AuthResult.failure(AuthError.AccountDisabled);
        else if(e.code == AuthError.TooManyRequests.code)   return AuthResult.failure(AuthError.TooManyRequests);
        return AuthResult.failure(AuthError.Unknown);
      } catch(e) {
        return AuthResult.failure(AuthError.Unknown);
      }
    });
  }

  bool get canSignInWithEmailAndPassword => _authenticator.canSignInWithEmailAndPassword;
  bool get canSignInWithEmailAndLink => _authenticator.canSignInWithEmailAndLink;
  bool get canSignInWithGoogle => _authenticator.canSignInWithGoogle;
  bool get canSignInWithApple => _authenticator.canSignInWithApple;
  bool get canSignInWithFacebook => _authenticator.canSignInWithFacebook;
  bool get canSignInWithPhone => _authenticator.canSignInWithPhone;

  Future<AuthUser> getCurrentUser() async => setAuthUser(await _authenticator.getCurrentUser());
  Future<String> getAuthToken({bool refresh = false}) => _authenticator.getAuthToken(refresh: refresh);
  Future<String> getIdToken({bool refresh = false}) => _authenticator.getIdToken(refresh: refresh);
  Future<AuthResult> createUserWithEmailAndLink(String email, String password) => _signIn(() => _authenticator.createUserWithEmailAndLink(email, password));
  Future<AuthResult> createUserWithEmailAndPassword(String email, String password) => _signIn(() => _authenticator.createUserWithEmailAndPassword(email, password));
  Future<AuthResult> signInWithEmailAndLink(String email, String password) => _signIn(() => _authenticator.signInWithEmailAndLink(email, password));
  Future<AuthResult> signInWithEmailAndPassword(String email, String password) => _signIn(() => _authenticator.signInWithEmailAndPassword(email, password));
  Future<AuthResult> signInWithGoogle() => _signIn(() => _authenticator.signInWithGoogle());
  Future<AuthResult> signInWithApple() => _signIn(() => _authenticator.signInWithApple());
  Future<AuthResult> signInWithFacebook() => _signIn(() => _authenticator.signInWithFacebook());
  Future<AuthResult> signInWithPhone() => _signIn(() => _authenticator.signInWithPhone());

  Future<void> signOut() async {
    await _authenticator.signOut();
    setAuthUser(null);
  }

  Future<AuthResult> _signIn(Future<AuthResult> Function() f) async {
    state = SigningIn;
    final result = await f();
    if(result.success) setAuthUser(result.user);
    return result;
  }
}

abstract class Authenticator {
  bool get canSignInWithEmailAndPassword;
  bool get canSignInWithEmailAndLink;
  bool get canSignInWithGoogle;
  bool get canSignInWithApple;
  bool get canSignInWithFacebook;
  bool get canSignInWithPhone;
  Stream<AuthUser> get onAuthStateChanged;
  Future<AuthUser> getCurrentUser();
  Future<String> getAuthToken({bool refresh = false});
  Future<String> getIdToken({bool refresh = false});
  Future<AuthResult> createUserWithEmailAndLink(String email, String password);
  Future<AuthResult> createUserWithEmailAndPassword(String email, String password);
  Future<AuthResult> signInWithEmailAndLink(String email, String password);
  Future<AuthResult> signInWithEmailAndPassword(String email, String password);
  Future<AuthResult> signInWithGoogle();
  Future<AuthResult> signInWithApple() => throw Exception('apple auth not yet supported');
  Future<AuthResult> signInWithFacebook() => throw Exception('apple auth not yet supported');
  Future<AuthResult> signInWithPhone() => throw Exception('apple auth not yet supported');
  Future<void> signOut();
}

class AuthUser {
  final String uid;
  final String name;
  final String avatar;
  AuthUser({this.uid, this.name, this.avatar});
  bool get isAnonymous => uid.isEmptyOrNull;
  bool get isNotAnonymous => !isAnonymous;
}

class AuthResult {
  final bool success;
  final AuthUser user;
  final AuthError error;
  AuthResult.success(this.user) : success = true, error = null;
  AuthResult.failure(this.error) : success = false, user = null;
  bool get failure => !success;
}

enum AuthError { Unknown, AccountDisabled, EmailInvalid, EmailInUse, PasswordIncorrect, PasswordInvalid, TooManyRequests, AccountNotFound }

extension AuthErrorExt on AuthError {
  String get code {
    switch(this) {
      case AuthError.AccountDisabled: return 'ERROR_USER_DISABLED';
      case AuthError.AccountNotFound: return 'ERROR_USER_NOT_FOUND';
      case AuthError.EmailInvalid: return 'ERROR_INVALID_EMAIL';
      case AuthError.EmailInUse: return 'ERROR_EMAIL_ALREADY_IN_USE';
      case AuthError.PasswordIncorrect: return 'ERROR_WRONG_PASSWORD';
      case AuthError.PasswordInvalid: return 'ERROR_WEAK_PASSWORD';
      case AuthError.TooManyRequests: return 'ERROR_TOO_MANY_REQUESTS';
      case AuthError.Unknown:
      default: return 'Unknown error';
    }
  }
  String get message {
    switch(this) {
      case AuthError.AccountDisabled: return 'Account disabled';
      case AuthError.AccountNotFound: return 'Account not found';
      case AuthError.EmailInvalid: return 'Email is not valid';
      case AuthError.EmailInUse: return 'Email already in use';
      case AuthError.PasswordIncorrect: return 'Password is not correct';
      case AuthError.PasswordInvalid: return 'Password is not valid';
      case AuthError.TooManyRequests: return 'Account is locked';
      case AuthError.Unknown:
      default: return 'Unknown error';
    }
  }
}
