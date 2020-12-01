import 'dart:async';

import 'package:oobium_common/src/data/database.dart';
import 'package:oobium_common/src/websocket/websocket.dart';
import 'package:oobium_common_test/oobium_common_test.dart';
import 'package:test/test.dart';

Future<void> main() async {
  test('test server bind', () async {
    final server = await TestIsolate.start(TestServerWithDelay(path: 'test1.db', port: 8001));
    await ClientWebSocket.connect(port: 8001);
    expect(await server.dbBinderCount, 1);
  });
}

class TestType1 extends DataModel {
  final String name;
  TestType1({String id, this.name}) : super(id);
  TestType1.fromJson(data) : name = data['name'], super.fromJson(data);
  @override TestType1 copyWith({String id, String name}) => TestType1(id: id ?? this.id, name: name ?? this.name);
  @override Map<String, dynamic> toJson() => super.toJson()..['name'] = name;
}

class TestServerWithDelay extends TestDatabaseServer {

  TestServerWithDelay({String path, int port}) : super(path: path, port: port);

  @override
  FutureOr<void> onConfigure(Database db) {
    db.addBuilder<TestType1>((data) => TestType1.fromJson(data));
    return Future.delayed(Duration(seconds: 1));
  }

}

class TestServer extends TestDatabaseServer {

  TestServer({String path, int port}) : super(path: path, port: port);

  @override
  FutureOr<void> onConfigure(Database db) {
    db.addBuilder<TestType1>((data) => TestType1.fromJson(data));
  }

}
