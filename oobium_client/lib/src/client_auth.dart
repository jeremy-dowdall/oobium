import 'dart:async';

import 'package:flutter/services.dart';
import 'package:oobium/oobium.dart';
import 'package:oobium_client/src/auth.dart';

class ClientAuth extends Auth {

  ClientAuth(Authenticator authenticator) : super(authenticator, [Anonymous(), SigningIn(), SettingUp(), SignedIn()]);

  Future<AuthResult> signInOrCreate({String email, String password}) {
    if(email.isBlank) return Future.value(AuthResult.failure(AuthError.EmailInvalid));
    if(password.isBlank) return Future.value(AuthResult.failure(AuthError.PasswordInvalid));
    return signIn(() async {
      try {
        return await authenticator.signInWithEmailAndPassword(email, password);
      } on PlatformException catch(e) {
        if(e.code == AuthError.AccountNotFound.code) { // user does not exist, try creating
          try {
            return await authenticator.createUserWithEmailAndPassword(email, password);
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
}
