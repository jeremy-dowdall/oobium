import 'package:oobium_server/src/server.dart';

void main() {
  final server = Server();

  server.logger.errorConverter = (req, res, err, stack) {
    return 'ErrorConverter Example: $err';
  };

  server.logger.messageConverter = (req, res, msg) {
    return 'MessageConverter Example: $msg';
  };

  server.get('/', [(req, res) {
    print('test message');
    throw Exception('test error');
  }]);

  server.get('/custom', [(req, res) async {
    print('test message');
  }], logger: CustomLogger('message-2'));

  server.start();
}

class CustomLogger extends Logger {

  final String customMessage;
  CustomLogger(this.customMessage);

  @override
  String convertMessage(Request req, Response res, String message) {
    return customMessage;
  }
}