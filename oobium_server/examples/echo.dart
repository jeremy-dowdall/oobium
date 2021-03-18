import 'package:oobium_server/src/server.dart';

void main() {
  final server = Server();

  server.get('/echo/<test>', [(req, res) {
    return res.send(data: req['test']);
  }]);

  server.start();
}