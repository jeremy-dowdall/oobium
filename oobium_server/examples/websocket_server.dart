import 'package:oobium_server/oobium_server.dart';

void main() {
  final server = Server();

  server.get('/ws', [(req, res) async {
    final ws = await req.upgrade();
    ws.addHandler(FileQueryHandler('examples/db'));
    ws.addHandler(FileSendHandler('examples/db'));
    ws.start();
  }]);

  server.start();
}
