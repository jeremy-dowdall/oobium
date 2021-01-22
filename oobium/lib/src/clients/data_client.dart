import 'dart:async';

import 'package:meta/meta.dart';
import 'package:oobium/src/clients/auth_client.schema.gen.models.dart';
import 'package:oobium/src/clients/data_client.schema.gen.models.dart';
import 'package:oobium/src/data/executor.dart';
import 'package:oobium/src/database.dart';
import 'package:oobium/src/websocket.dart';

const SchemaName = '__schema__';

class DataStore {
  
  final Definition definition;
  final Database database;
  DataStore(this.definition, this.database);

  String get name => definition.name;
  String get access => definition.access;
}

class DataClient {

  final String root;
  final List<Definition> Function() create;
  final FutureOr<Database> Function(String root, Definition ds) builder;
  DataClient({@required this.root, @required this.create, @required this.builder});

  String get path => '$root/${_account?.uid}';

  Account _account;
  DataClientData _schema;
  StreamSubscription _schemaSub;
  final _datastores = <String, DataStore>{};
  WebSocket _socket;
  Executor _executor;

  T db<T extends Database>(String name) => _datastores[name]?.database;

  List<Definition> get schema => _schema?.getAll<Definition>()?.toList() ?? <Definition>[];

  Future<void> add(Definition def) => (_schema..put(def)).flush();

  void remove(String name) => _schema.remove(_datastores[name]?.definition?.id);

  Future<void> setAccount(Account account) async {
    if(account?.uid != _account?.uid) {
      await _executor?.cancel();
      _executor = null;

      if(_account != null) {
        _schemaSub.cancel();
        _schemaSub = null;
        await _schema.close();
        _schema = null;
        await Future.forEach<DataStore>(_datastores.values, (ds) => ds.database.close());
        _datastores.clear();
      }

      _account = account;

      if(_account != null) {
        _schema = await DataClientData(path).open(onUpgrade: (event) async* {
          for(var def in create()) {
            yield(def.toDataRecord());
          }
        });
        await _addAll(_schema.getAll<Definition>());
        _schemaSub = _schema.streamAll<Definition>().listen((event) => _onDataModelEvent(event));
        await _bind(_schema, SchemaName);
      }
    }
  }

  Future<void> setSocket(WebSocket socket) async {
    if(socket != _socket) {
      await _executor?.cancel();
      _executor = null;

      if(_socket != null) {
        _schema?.unbind(_socket, name: SchemaName);
        for(var ds in _datastores.values) {
          ds.database.unbind(_socket, name: ds.name);
        }
      }

      _socket = socket;

      if(_socket != null) {
        _bind(_schema, SchemaName);
        for(var ds in _datastores.values) {
          _bind(ds.database, ds.name);
        }
      }
    }
  }

  void _bind(Database db, String name) {
    if(_socket != null && db != null) {
      _executor ??= Executor();
      _executor.add(() => db.bind(_socket, name: name));
    }
  }

  Future<void> _add(Definition def) async {
    if(!_datastores.containsKey(def.name)) {
      final db = await builder(path, def);
      if(db != null) {
        _datastores[def.name] = DataStore(def, await db.open());
        _bind(db, def.name);
      }
    }
  }

  Future<void> _addAll(Iterable<Definition> defs) => Future.forEach<Definition>(defs, (def) => _add(def));

  DataStore _remove(String name) {
    final ds = _datastores.remove(name);
    ds?.database?.unbind(_socket, name: name);
    return ds;
  }

  void _removeAll(Iterable<Definition> defs) {
    for(var def in defs) {
      _remove(def.name);
    }
  }

  Future<void> _onDataModelEvent(DataModelEvent<Definition> event) async {
    print('client(${root.split('/').last}) onDataModelEvent($event)');
    await _addAll(event.puts);
    _removeAll(event.removes);
  }
}
