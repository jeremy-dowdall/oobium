import 'package:meta/meta.dart';
import 'package:corsac_jwt/corsac_jwt.dart';

class FirebaseToken {

  final String/*?*/ uid;
  final String/*?*/ name;
  final String/*?*/ picture;
  final String/*?*/ email;
  final String/*?*/ emailVerified;
  final List<String> errors;
  final bool validated;

  FirebaseToken({
    this.uid,
    this.name,
    this.picture,
    this.email,
    this.emailVerified,
    List<String> errors,
    bool validated
  }) :
    errors = errors ?? [],
    validated = validated ?? (uid != null)
  ;
  
  bool isValid() => validated && (uid != null) && errors.isEmpty;

  Map get data => {
    if(name != null)          'name':          name,
    if(picture != null)       'picture':       picture,
    if(email != null)         'email':         email,
    if(emailVerified != null) 'emailVerified': emailVerified,
  };

  static FirebaseToken decode({@required String token, String projectId, Map<String, String> publicKeys}) {
    final jwt = (token != null) ? JWT.parse(token) : null;
    final errors = <String>[];
    final validated = token != null && (projectId != null || publicKeys != null);

    if(validated) {
      // https://firebase.google.com/docs/auth/admin/verify-id-tokens#verify_id_tokens_using_a_third-party_jwt_library

      // validate header
      if(jwt.headers['alg'] != 'RS256') errors.add("invalid value for header['alg']: ${jwt.headers['alg']}");
      if(!publicKeys.containsKey(jwt.headers['kid'])) errors.add("missing public key: ${jwt.headers['kid']}");

      // validate payload (claims)
      final validator = JWTValidator()
        ..subject = jwt.subject
        ..audience = projectId
        ..issuer = 'https://securetoken.google.com/$projectId';
      errors.addAll(validator.validate(jwt));

      // validate signature
      final key = publicKeys[jwt.headers['kid']];
      final signer = JWTRsaSha256Signer(publicKey: key);
      if(!jwt.verify(signer)) errors.add('invalid signature');
    }

    return FirebaseToken(
      uid:           jwt?.subject,
      name:          (jwt.claims != null) ? jwt.claims['name'] : null,
      picture:       (jwt.claims != null) ? jwt.claims['picture'] : null,
      email:         (jwt.claims != null) ? jwt.claims['email'] : null,
      emailVerified: (jwt.claims != null) ? jwt.claims['emailVerified'] : false,
      errors:        errors,
      validated:     validated
    );
  }
}