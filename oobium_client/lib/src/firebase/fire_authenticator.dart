import 'package:firebase_auth/firebase_auth.dart' hide AuthResult;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:oobium_common/oobium_common.dart';

class FireAuthenticator extends Authenticator {

  @override
  Stream<AuthUser> get onAuthStateChanged => FirebaseAuth.instance.onAuthStateChanged.map((user) => user.authUser);

  @override
  Future<AuthUser> getCurrentUser() async => (await FirebaseAuth.instance.currentUser()).authUser;

  @override
  String get type => 'FireToken';

  @override bool get canSignInWithEmailAndPassword => true;
  @override bool get canSignInWithEmailAndLink => false;
  @override bool get canSignInWithGoogle => true;
  @override bool get canSignInWithApple => true;
  @override bool get canSignInWithFacebook => false;
  @override bool get canSignInWithPhone => false;

  @override
  Future<String> getIdToken({bool refresh = false}) async {
    final fireUser = await FirebaseAuth.instance.currentUser();
    var fireToken = await fireUser?.getIdToken(refresh: refresh);
    if(fireToken?.expirationTime?.isAfter(DateTime.now()) == false) {
      fireToken = await fireUser.getIdToken(refresh: true);
    }
    return fireToken?.token;
  }

  @override
  Future<AuthResult> createUserWithEmailAndLink(String email, String password) => throw UnimplementedError('email and link auth not yet supported');

  @override
  Future<AuthResult> createUserWithEmailAndPassword(String email, String password) async {
    final result = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: password);
    return AuthResult.success(result.user.authUser);
  }

  @override
  Future<AuthResult> signInWithEmailAndLink(String email, String password) => throw UnimplementedError('email and link auth not yet supported');

  @override
  Future<AuthResult> signInWithEmailAndPassword(String email, String password) async {
    final result = await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);
    return AuthResult.success(result.user.authUser);
  }

  @override
  Future<AuthResult> signInWithGoogle() async {
    final googleUser = await GoogleSignIn().signIn();
    if(googleUser == null) {
      return AuthResult.failure(AuthError.Unknown);
    } else {
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.getCredential(idToken: googleAuth.idToken, accessToken: googleAuth.accessToken);
      final result = await FirebaseAuth.instance.signInWithCredential(credential);
      return AuthResult.success(result.user.authUser);
    }
  }

  @override
  Future<AuthResult> signInWithApple() => throw UnimplementedError('apple auth not yet supported');

  @override
  Future<AuthResult> signInWithFacebook() => throw UnimplementedError('facebook auth not yet supported');

  @override
  Future<AuthResult> signInWithPhone() => throw UnimplementedError('phone auth not yet supported');

  @override
  Future<void> signOut() => FirebaseAuth.instance.signOut();

}

extension FirebaseUserExt on FirebaseUser {
  AuthUser get authUser => AuthUser(
    id: this?.uid ?? '',
    name: this?.displayName ?? '',
    avatar: this?.photoUrl ?? '',
  );
}
