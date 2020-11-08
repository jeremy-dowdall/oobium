import 'dart:async';

import 'package:oobium_common/src/json.dart';
import 'package:oobium_common/src/string.extensions.dart';

abstract class AuthStateValue { }
class Anonymous extends AuthStateValue {}
class SigningIn extends AuthStateValue {}
class SettingUp extends AuthStateValue {}
class SignedIn extends AuthStateValue {}

abstract class Auth {

  final Authenticator authenticator;
  final List<AuthStateValue> _states;
  int statePosition = 0;
  StreamSubscription _authSubscription;
  Auth(Authenticator authenticator, List<AuthStateValue> states) :
    authenticator = authenticator,
    _states = List<AuthStateValue>.unmodifiable(states)
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
    _authSubscription = authenticator.onAuthStateChanged?.listen((authUser) => setAuthUser(authUser));
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
  String get uid => _authUser?.id;
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

  bool get canSignInWithEmailAndPassword => authenticator.canSignInWithEmailAndPassword;
  bool get canSignInWithEmailAndLink => authenticator.canSignInWithEmailAndLink;
  bool get canSignInWithGoogle => authenticator.canSignInWithGoogle;
  bool get canSignInWithApple => authenticator.canSignInWithApple;
  bool get canSignInWithFacebook => authenticator.canSignInWithFacebook;
  bool get canSignInWithPhone => authenticator.canSignInWithPhone;

  Future<AuthResult> signIn(Future<AuthResult> Function() authenticatorFunction) async {
    state = SigningIn;
    final result = await authenticatorFunction();
    if(result.success) setAuthUser(result.user);
    return result;
  }

  Future<void> signOut() async {
    await authenticator.signOut();
    setAuthUser(null);
  }
}

abstract class Authenticator {
  String get type;
  Stream<AuthUser> get onAuthStateChanged;
  Future<AuthUser> getCurrentUser();
  Future<String> getIdToken({bool refresh = false});
  Future<String> getAuthToken({bool refresh = false}) async => '$type ${await getIdToken(refresh: refresh)}';
  bool get canSignInWithEmailAndPassword => false;
  bool get canSignInWithEmailAndLink => false;
  bool get canSignInWithGoogle => false;
  bool get canSignInWithApple => false;
  bool get canSignInWithFacebook => false;
  bool get canSignInWithPhone => false;
  Future<AuthResult> createUserWithEmailAndLink(String email, String password) => throw Exception('create email and link auth not supported');
  Future<AuthResult> createUserWithEmailAndPassword(String email, String password) => throw Exception('create email and password auth not supported');
  Future<AuthResult> signInWithEmailAndLink(String email, String password) => throw Exception('email and link auth not supported');
  Future<AuthResult> signInWithEmailAndPassword(String email, String password) => throw Exception('email and password auth not supported');
  Future<AuthResult> signInWithGoogle() => throw Exception('google auth not supported');
  Future<AuthResult> signInWithApple() => throw Exception('apple auth not supported');
  Future<AuthResult> signInWithFacebook() => throw Exception('facebook auth not supported');
  Future<AuthResult> signInWithPhone() => throw Exception('phone auth not supported');
  Future<void> signOut();
}

class AuthUser {
  final String id;
  final String name;
  final String avatar;
  AuthUser({this.id, this.name, this.avatar});
  AuthUser.fromJson(data) : id = Json.field(data, 'uid'), name = Json.field(data, 'name'), avatar = Json.field(data, 'avatar');
  bool get isAnonymous => id.isEmptyOrNull;
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
