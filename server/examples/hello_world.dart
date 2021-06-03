import 'package:oobium_server/src/server.dart';

void main() async {
  final server = Server();

  server.get('/', [(req, res) {
    return res.send(data: 'hello world!');
  }]);

  await server.start();
}