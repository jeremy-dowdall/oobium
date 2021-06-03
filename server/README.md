# oobium server
Server Side Dart development.

## Usage

A simple usage example:

```dart
import 'package:oobium_server/src/server.dart';

void main() {
  final server = Server();

  server.get('/', [(req, res) {
    return res.send(data: 'hello world!');
  }]);

  server.start();
}
```
