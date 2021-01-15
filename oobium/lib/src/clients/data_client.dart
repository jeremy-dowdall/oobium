import 'dart:async';

import 'package:oobium/oobium.dart';
import 'package:oobium/src/clients/account.schema.gen.models.dart';
import 'package:oobium/src/clients/storage.schema.gen.models.dart';
import 'package:oobium/src/database.dart';
import 'package:oobium/src/websocket.dart';

class DataStore {
  
  final DbDefinition definition;
  final Database database;
  DataStore(this.definition, this.database);

  String get name => definition.name;
  bool get isPrivate => isNotShared;
  bool get isNotPrivate => !isPrivate;
  bool get isShared => definition.shared;
  bool get isNotShared => !isShared;

}

class DataClient {

  final String root;
  final List<DbDefinition> Function() create;
  final Database Function(String root, DbDefinition ds) builder;
  DataClient({@required this.root, @required this.create, @required this.builder});

  Account _account;
  final _datastores = <String, DataStore>{};

  bool _dataBound = false;
  bool get isBound => _dataBound;
  bool get isNotBound => !isBound;

  WebSocket _socket;
  bool get isConnected => _socket?.isConnected == true;
  bool get isNotConnected => !isConnected;

  T db<T extends Database>(String name) => _datastores[name]?.database;

  Future<void> setAccount(Account account) async {
    if(account?.uid != _account?.uid) {
      if(_account != null) {
        await Future.forEach<DataStore>(_datastores.values, (ds) => ds.database.close());
        _datastores.clear();
      }

      _account = account;

      if(_account != null) {
        final path = '$root/${_account.uid}';
        final ds = await _getStorageDataStore(path);
        for(var def in _getDefinitions(ds.database)) {
          final db = builder(path, def);
          if(db != null) {
            _datastores[def.name] = DataStore(def, await db.open());
          }
        }
        await _updateBindings();
      }
    }
  }

  Future<void> setSocket(WebSocket socket) async {
    _socket = socket;
    await _updateBindings();
  }

  Future<DataStore> _getStorageDataStore(String path) async {
    final data = DataStore(
      DbDefinition(name: '_', shared: false),
      await StorageData(path).open()
    );
    _datastores[data.name] = data;
    return data;
  }

  Iterable<DbDefinition> _getDefinitions(Database data) {
    final definitions = data.getAll<DbDefinition>();
    if(definitions.isNotEmpty) {
      return definitions;
    } else {
      for(var def in create()) {
        data.put(def);
      }
      return data.getAll<DbDefinition>();
    }
  }

  Future<void> _updateBindings() async {
    if(_account == null) {
      return; // nothing to do
    }
    if(isConnected) {
      for(var ds in _datastores.values) {
        await _bind(ds, _socket);
      }
      _dataBound = true;
    } else {
      for(var ds in _datastores.values) {
        ds.database.unbind(_socket);
      }
      _dataBound = false;
    }
  }

  Future<void> _bind(DataStore ds, WebSocket socket) async {
    print('client socket.put(${ds.definition})');
    final result = await socket.put('/data/db', ds.definition);
    if(result.isSuccess) {
      print('client bind:${ds.name}');
      await ds.database.bind(socket, name: ds.name);
    }
  }
}
