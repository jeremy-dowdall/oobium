import 'package:oobium_server/oobium_server.dart';

main() async {
  final server = await Server();

  server.get('/', [(req) => 'hello world']);
  server.get('/echo/<msg>', [(req) => req['msg']]);

  server.start();
}