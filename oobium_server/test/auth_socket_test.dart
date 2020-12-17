import 'dart:async';

import 'package:oobium_common/oobium_common.dart';
import 'package:oobium_common_test/oobium_common_test.dart';
import 'package:oobium_server/src/auth2/auth.schema.gen.models.dart';
import 'package:oobium_server/src/auth2/auth_server.dart';
import 'package:test/test.dart';

Future<void> main() async {
  final path = 'test-data';

  test('test invitation process', () async {
    final db = AuthData('$path/auth.db');
    await db.reset();
    final admin = db.put(User(name: 'admin', token: Token(), role: 'admin'));
    await db.close();

    final server = await TestHybrid.start(TestServer(port: 8001, dbPath: '$path/auth.db'));

    final clientA = await AuthSocket.connect(port: 8001, uid: admin.id, token: admin.token.id);
    expect(clientA.uid, admin.id);
    expect(clientA.token, admin.token.id);

    final installCode = await clientA.newInstallToken();
    expect(installCode.length, 6);

    await Future.delayed(Duration(seconds: 10));
    clientA.onApprove = () async {
      await Future.delayed(Duration(seconds: 10));
      return true;
    };

    final clientB = await AuthSocket.connect(port: 8001, token: installCode);
    expect(clientB.uid, isNotEmpty);
    expect(clientB.uid, isNot(clientA.uid));
    expect(clientB.token, isNotEmpty);
    expect(clientB.token, isNot(clientA.token));

    await db.open();
    expect(db.getAll<User>().length, 2);
    expect(db.getAll<Token>().length, 2);

    await db.close();
    await server.stop();
    await clientA.close();
    await clientB.close();
  });
}

class TestServer extends TestHybrid {

  final int port;
  final String dbPath;
  TestServer({this.port, this.dbPath});

  AuthServer _server;

  @override
  Future<void> onStart() async {
    _server = AuthServer(port: port, dbPath: dbPath);
    await _server.start();
  }

  @override
  Future<void> onStop() async {
    await _server.stop();
  }

  @override
  FutureOr onMessage(String path, data) {
  }
}
