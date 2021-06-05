import 'dart:async';

import 'package:objectid/objectid.dart';
import 'package:oobium/src/clients/auth_client.schema.g.dart';
import 'package:oobium/src/clients/data_client.schema.g.dart';
import 'package:oobium/src/datastore/executor.dart';
import 'package:oobium/src/datastore.dart';
import 'package:oobium/src/websocket.dart';

const SchemaName = '__schema__';

class DefinedDataStore {
  
  final Definition definition;
  final DataStore datastore;
  DefinedDataStore(this.definition, this.datastore);

  ObjectId get id => definition.id;
  String get name => definition.name;
  String? get access => definition.access;
}

class SchemaEvent {
  final Definition? added;
  final Definition? removed;
  SchemaEvent._(this.added, this.removed);
}

class DataClient {

  final String _root;
  final List<Definition> Function() _create;
  final FutureOr<DataStore?> Function(String root, Definition ds) _builder;
  DataClient({
    required String root,
    required FutureOr<DataStore?> Function(String root, Definition ds) builder,
    required List<Definition> Function() create}) : _root = root, _create = create, _builder = builder;

  String get _path => '$_root/${_account?.uid}';

  Account? _account;
  DataClientData? _schema;
  WebSocket? _socket;
  Executor? _executor;
  final _datastores = <ObjectId, DefinedDataStore>{};
  final _updates = <ObjectId, Completer>{};
  final _controller = StreamController<SchemaEvent>.broadcast();

  T? ds<T extends DefinedDataStore>(ObjectId id) => _datastores[id]?.datastore as T?;

  Future<void> add(Definition def) => _update(def.id, () => _schema!.put(def));

  Future<void> remove(Definition def) => _datastores.containsKey(def.id) ? _update(def.id, () => _schema!.remove(def)) : Future.value();

  List<Definition> get schema => _schema?.getDefinitions().toList() ?? <Definition>[];

  Stream<SchemaEvent> get events => _controller.stream;

  Future<void> setAccount(Account? account) async {
    if(account?.uid != _account?.uid) {
      await _executor?.cancel();
      _executor = null;

      if(_account != null) {
        await _schema?.close();
        _schema = null;
        await Future.forEach<DefinedDataStore>(_datastores.values, (ds) => ds.datastore.close());
        _datastores.clear();
      }

      _account = account;

      if(_account != null) {
        _schema = await DataClientData(_path).open(onUpgrade: (event) async* {
          for(var def in _create()) {
            yield(def.toDataRecord());
          }
        });
        await _addAll(_schema!.getDefinitions());
        _schema!.streamDefinitions().listen((event) => _onDataModelEvent(event));
        // TODO binding
        // await _bind(_schema!, SchemaName);
      }
    }
  }

  Future<void> setSocket(WebSocket? socket) async {
    if(socket != _socket) {
      await _executor?.cancel();
      _executor = null;

      if(_socket != null) {
        // TODO binding
        // _schema?.unbind(_socket!, name: SchemaName);
        for(var ds in _datastores.values) {
          ds.datastore.unbind(_socket!, name: ds.id.hexString);
        }
      }

      _socket = socket;

      if(_socket != null) {
        // TODO binding
        // _bind(_schema, SchemaName);
        for(var ds in _datastores.values) {
          _bind(ds.datastore, ds.id.hexString);
        }
      }
    }
  }

  Future<void> _bind(DataStore? ds, String id) {
    if(_socket != null && ds != null) {
      _executor ??= Executor();
      return _executor!.add(() {if(_socket != null) ds.bind(_socket!, name: id);});
    } else {
      return Future.value();
    }
  }

  Future<void> _add(Definition def) async {
    if(!_datastores.containsKey(def.id)) {
      final ds = await _builder(_path, def);
      if(ds != null) {
        _datastores[def.id] = DefinedDataStore(def, await ds.open());
        _bind(ds, def.id.hexString);
      }
    }
    _complete(def.id);
    _controller.add(SchemaEvent._(def, null));
  }

  Future<void> _addAll(Iterable<Definition> defs) => Future.forEach<Definition>(defs, (def) => _add(def));

  void _remove(Definition def) {
    final ds = _datastores.remove(def.id);
    ds?.datastore.unbind(_socket!, name: def.id.hexString);
    _complete(def.id);
    if(ds != null) {
      _controller.add(SchemaEvent._(null, ds.definition));
    }
  }

  void _removeAll(Iterable<Definition> defs) {
    for(final def in defs) {
      _remove(def);
    }
  }

  void _complete(ObjectId id) {
    _updates.remove(id)?.complete();
  }

  Future<void> _update(ObjectId id, Function() op) async {
    await _updates[id]?.future;
    _updates[id] = Completer();
    op();
    return _updates[id]?.future;
  }

  Future<void> _onDataModelEvent(DataModelEvent<Definition> event) async {
    // print('dataClient(${root.split('/').last})._onDataModelEvent($event)');
    await _addAll(event.puts);
    _removeAll(event.removes);
  }
}
