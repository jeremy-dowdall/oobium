import 'package:oobium_server/src/server.dart';

void main() {
  final server = Server();

  server.logger.errorConverter = (req, err, stack) {
    return 'ErrorConverter Example: $err';
  };

  server.logger.messageConverter = (req, msg) {
    return 'MessageConverter Example: $msg';
  };

  server.get('/', [(req) {
    print('test message');
    throw Exception('test error');
  }]);

  server.get('/custom', [(req) {
    print('test message');
  }], logger: CustomLogger('message-2'));

  server.start();
}

class CustomLogger extends Logger {

  final String customMessage;
  CustomLogger(this.customMessage);

  @override
  String convertMessage(Request req, String message) {
    return customMessage;
  }
}