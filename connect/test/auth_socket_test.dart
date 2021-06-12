import 'dart:async';

import 'package:oobium/oobium.dart';
import 'package:test/test.dart';

import '../../server/test/test_client.dart';

void main() {

  setUpAll(() => TestClient.clean('test-data'));
  tearDownAll(() => TestClient.clean('test-data'));

  test('invitation process', () async {
    final server = await TestClient.start('test-data/test-01', 8001, ['auth']);

    final user = await AdminClient(port: 8001).createUser('test-1');
    expect(user['id'], isNotEmpty);
    expect(user['token'], isNotEmpty);

    print('connecting');
    final clientA = await AuthSocket().connect(port: 8001, uid: user['id'], token: user['token']);
    print('connected');
    expect(clientA.uid, user['id']);
    expect(clientA.token, user['token']);

    print('get installCode');
    final installCode = await clientA.newInstallToken();
    print('got installCode: $installCode');
    expect(installCode?.length, 6);

    await Future.delayed(Duration(seconds: 2));
    clientA.onApprove = () async {
      await Future.delayed(Duration(seconds: 2));
      return true;
    };

    final clientB = await AuthSocket().connect(port: 8001, token: installCode);
    expect(clientB.uid, isNotEmpty);
    expect(clientB.uid, isNot(clientA.uid));
    expect(clientB.token, isNotEmpty);
    expect(clientB.token, isNot(clientA.token));
  });
}
