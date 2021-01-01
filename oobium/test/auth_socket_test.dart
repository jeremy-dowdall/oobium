import 'dart:async';

import 'package:oobium/src/clients/admin_client.dart';
import 'package:oobium/src/clients/auth_socket.dart';
import 'package:test/test.dart';

import 'test_client.dart';

Future<void> main() async {

  setUpAll(() => TestClient.clean('test-data'));
  tearDownAll(() => TestClient.clean('test-data'));

  test('test invitation process', () async {
    final server = await TestClient.start('test-data/test-01', 8001);

    final admin = await AdminClient(port: 8001).getAccount();
    expect(admin.id, isNotEmpty);
    expect(admin.token, isNotEmpty);

    print('connecting');
    final clientA = await AuthSocket().connect(port: 8001, uid: admin.id, token: admin.token);
    print('connected');
    expect(clientA.uid, admin.id);
    expect(clientA.token, admin.token);

    print('get installCode');
    final installCode = await clientA.newInstallToken();
    print('got installCode: $installCode');
    expect(installCode.length, 6);

    await Future.delayed(Duration(seconds: 10));
    clientA.onApprove = () async {
      await Future.delayed(Duration(seconds: 10));
      return true;
    };

    final clientB = await AuthSocket().connect(port: 8001, token: installCode);
    expect(clientB.uid, isNotEmpty);
    expect(clientB.uid, isNot(clientA.uid));
    expect(clientB.token, isNotEmpty);
    expect(clientB.token, isNot(clientA.token));
  });
}
