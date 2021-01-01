import 'package:oobium/src/server/server.dart';

void main() {
  final server = Server();

  server.get('/', [(req, res) {
    return res.send(data: 'hello world!');
  }]);

  server.start();
}