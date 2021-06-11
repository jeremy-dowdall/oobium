import 'dart:async';

import 'package:objectid/objectid.dart';
import 'package:oobium/src/datastore/data.dart';
import 'package:oobium/src/datastore/sync.dart';
import 'package:oobium/src/datastore.dart';
import 'package:oobium/src/websocket.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';

import 'utils/test_models.dart';

Future<void> main() async {

  setUpAll(() async => await cleanHybrid('test-data'));
  tearDownAll(() async => await cleanHybrid('test-data'));

  group('sync events', () {
    test('test data event serialization', () {
      final record = DataRecord.fromModel(TestType1(name: 'test-model-01'));
      final event = DataEvent('test-id-01', [record]);
      final json = event.toJson();
      expect(json['history'], ['test-id-01']);
      expect(json['records'], [record.toJson()]);

      final restored = DataEvent.fromJson(json);
      expect(restored.history, {'test-id-01'});
      expect(restored.records, isNotEmpty);
      expect(restored.records.first.toJson(), record.toJson());
    });
  });

  group('sync lifecycle', () {
    test('test no id first open', () async {
      final path = nextPath();
      final data = await Data(path).open();
      final sync = Sync(data, (_) => null, () => []);
      await sync.open();
      expect(sync.id, isNull);
    });

    test('test id auto-generated on replicate and maintained on open', () async {
      final path = nextPath();
      final data = await Data(path).open();
      final sync = Sync(data, (_) => null, () => []);
      await sync.open();
      await sync.createReplicant();
      expect(sync.id, isNotNull);
      final id = sync.id;
      await sync.close();
      expect(sync.id, isNull);
      await sync.open();
      expect(sync.id, id);
    });
  });

  test('test replication reset', () async {
    final port = nextPort();
    final server = await serverHybrid(nextPath(), port);
    final model = await server.dsPut(TestType1(name: 'test-01'));

    final ds = datastore(nextPath());
    await ds.reset(socket: await WebSocket().connect(port: port));

    expect(ds.size, 1);
    expect(ds.get<TestType1>(model.id)?.name, model.name);
  });

  test('test replication bind with no data', () async {
    final port = nextPort();
    await serverHybrid(nextPath(), port);

    final ds = await datastore(nextPath()).open();
    await ds.bind(await WebSocket().connect(port: port));

    expect(ds.size, 0);
  });

  test('test replication bind with server data', () async {
    final port = nextPort();
    final server = await serverHybrid(nextPath(), port);
    final model = await server.dsPut(TestType1(name: 'test-01'));

    final ds = await datastore(nextPath()).open();
    await ds.bind(await WebSocket().connect(port: port));

    expect(ds.size, 1);
    expect(ds.get<TestType1>(model.id)?.name, model.name);
  });

  test('test replication bind with client data', () async {
    final port = nextPort();
    final server = await serverHybrid(nextPath(), port);

    final ds = await datastore(nextPath()).open();
    final model = ds.put(TestType1(name: 'test-01'));
    await ds.bind(await WebSocket().connect(port: port));

    expect(ds.size, 1);
    expect(await server.dsModelCount, 1);
    expect((await server.dsGet(model.id))?.name, model.name);
  });

  test('test replication bind with mixed data', () async {
    final port = nextPort();
    final server = await serverHybrid(nextPath(), port);
    final model1 = await server.dsPut(TestType1(name: 'test-01'));

    final ds = await datastore(nextPath()).open();
    final model2 = ds.put(TestType1(name: 'test-02'));
    await ds.bind(await WebSocket().connect(port: port));

    expect(ds.size, 2);
    expect(ds.get<TestType1>(model1.id)?.name, model1.name);
    expect(ds.get<TestType1>(model2.id)?.name, model2.name);
    expect(await server.dsModelCount, 2);
    expect((await server.dsGet(model1.id))?.name, model1.name);
    expect((await server.dsGet(model2.id))?.name, model2.name);
  });

  test('test bind(1 <-> 2) with pre-existing data', () async {
    final port = nextPort();
    final server = await serverHybrid(nextPath(), port);
    final client = await WebSocket().connect(port: port);

    final ds2 = datastore(nextPath());
    await ds2.reset(socket: client);

    final m1 = TestType1(name: 'test01');
    final m2 = TestType1(name: 'test02');

    await server.dsPut(m1);
    ds2.put(m2);

    await ds2.bind(client);

    expect(await server.dsModelCount, 2);
    expect(await server.dsModelCount, ds2.size);
    expect((await server.dsGet(m1.id))?.name, 'test01');
    expect((await server.dsGet(m2.id))?.name, 'test02');
    expect(ds2.get<TestType1>(m1.id)?.name, 'test01');
    expect(ds2.get<TestType1>(m2.id)?.name, 'test02');
  });

  test('test bind(1 <-> 2) fresh', () async {
    final port = nextPort();
    final server = await serverHybrid(nextPath(), port);
    final client = await WebSocket().connect(port: port);

    final ds = datastore(nextPath());
    await ds.reset(socket: client);

    await ds.bind(client);

    final m1 = TestType1(name: 'test01');
    await server.dsPut(m1);
    expect(await server.dsModelCount, 1);
    expect(ds.size, 1);
    expect(ds.get(m1.id), isNotNull);
    expect(ds.get<TestType1>(m1.id)?.name, 'test01');

    final m2 = TestType1(name: 'test02');
    ds.put(m2);
    await ds.flush();
    expect(ds.size, 2);
    expect(await server.dsModelCount, ds.size);
    expect((await server.dsGet(m2.id))?.name, 'test02');
  });

  test('test bind(2 <-> 1 <-> 3)', () async {
    final port = nextPort();
    final server = await serverHybrid(nextPath(), port);
    final client1 = await WebSocket().connect(port: port);
    final client2 = await WebSocket().connect(port: port);

    final ds1 = datastore(nextPath());
    await ds1.reset(socket: client1);
    final ds2 = datastore(nextPath());
    await ds2.reset(socket: client2);

    await ds1.bind(client1);
    await ds2.bind(client2);

    expect(await server.dsModelCount, 0);
    expect(ds1.size, 0);
    expect(ds2.size, 0);

    final m1 = TestType1(name: 'test01');
    await server.dsPut(m1);
    expect(await server.dsModelCount, 1);
    expect(ds1.size, 1);
    expect(ds2.size, 1);
    expect((await server.dsGet(m1.id))?.name, 'test01');
    expect(ds1.get<TestType1>(m1.id)?.name, 'test01');
    expect(ds2.get<TestType1>(m1.id)?.name, 'test01');

    final m2 = TestType1(name: 'test02');
    ds1.put(m2);
    await ds1.flush();
    expect(await server.dsModelCount, 2);
    expect(ds1.size, 2);
    expect(ds2.size, 2);
    expect((await server.dsGet(m2.id))?.name, 'test02');
    expect(ds1.get<TestType1>(m2.id)?.name, 'test02');
    expect(ds2.get<TestType1>(m2.id)?.name, 'test02');

    final m3 = TestType1(name: 'test03');
    ds2.put(m3);
    await ds2.flush();
    expect(await server.dsModelCount, 3);
    expect(ds1.size, 3);
    expect(ds2.size, 3);
    expect((await server.dsGet(m3.id))?.name, 'test03');
    expect(ds1.get<TestType1>(m3.id)?.name, 'test03');
    expect(ds2.get<TestType1>(m3.id)?.name, 'test03');
  });

  test('test bind 2 databases on 1 socket', () async {
    final port = nextPort();
    final server = await serverHybrid(nextPath(), port, ['ds1', 'ds2']);
    final socket = await WebSocket().connect(port: port);

    final ds1 = await datastore(nextPath()).open();
    final ds2 = await datastore(nextPath()).open();

    await ds1.bind(socket, name: 'ds1');
    await ds2.bind(socket, name: 'ds2');
  });
}

DataStore datastore(String path) => DataStore(path, builders: [(data) => TestType1.fromJson(data)]);
Future<DsTestServerClient> serverHybrid(String path, int port, [List<String> databases=const[]]) => DsTestServerClient.start(path, port);
Future<void> cleanHybrid(String path) => DsTestServerClient.clean(path);

int dsCount = 0;
int serverCount = 0;
String nextPath() => 'test-data/datastore-sync-test-${dsCount++}';
int nextPort() => 8000 + (serverCount++);

class DsTestServerClient {

  static Future<DsTestServerClient> start(String path, int port, [List<String> databases=const[]]) async {
    final server = DsTestServerClient(spawnHybridUri('datastore_sync_test_server.dart', message: ['serve', path, port, databases]));
    await server.ready;
    return server;
  }

  static Future<void> clean(String path) {
    return DsTestServerClient(spawnHybridUri('datastore_sync_test_server.dart', message: ['clean', path])).ready;
  }

  final _ready = Completer();
  final StreamChannel<Object?> channel;
  DsTestServerClient(this.channel) {
    channel.stream.listen((msg) {
      if(msg == 'ready') {
        _ready.complete();
      }
      else {
        final completer = this.completer;
        if(completer != null && !completer.isCompleted) {
          if(msg is Map) {
            completer.complete(TestType1.fromJson(msg));
          } else {
            completer.complete(msg);
          }
          this.completer = null;
        }
      }
    }, onDone: () {
      print('done');
    }, onError: (e,s) {
      print('wtf? $e\n$s');
    });
  }

  Future<void> get ready => _ready.future;

  Future<TestType1?> dsGet(ObjectId id) => _send<TestType1>('/ds/get', '$id');
  Future<TestType1> dsPut(DataModel model) => _send<TestType1>('/ds/put', model.toJson());

  Future<int> get dsModelCount => _send<int>('/ds/count/models');

  Completer? completer;
  Future<T> _send<T>(String path, [dynamic data]) async {
    await completer?.future;
    completer = Completer<T>();
    channel.sink.add([path, data]);
    return completer!.future as Future<T>;
  }
}
