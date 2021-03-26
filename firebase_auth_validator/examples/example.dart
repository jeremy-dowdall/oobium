import 'package:firebase_auth_validator/firebase_auth_validator.dart';
import 'package:oobium_server/oobium_server.dart';

void main() {
  final server = Server();

  server.get('/', [(req, res) {
    return res.send(data: 'hello world!');
  }]);

  server.get('/private', [auth, (req, res) {
    return res.send(data: 'hello world!');
  }]);

  server.addService(AuthService(validators: [FirebaseAuthValidator()]));

  server.start();
}
