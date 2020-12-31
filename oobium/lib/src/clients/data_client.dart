import 'dart:async';

import 'package:oobium/src/clients/account.schema.gen.models.dart';
import 'package:oobium/src/database.dart';
import 'package:oobium/src/websocket.dart';

class DataClient {

  final String root;
  final String name;
  final FutureOr<Database> Function(String path) builder;
  DataClient({this.root, this.name, this.builder});

  Account _account;

  Database _data;
  bool _dataBound = false;
  bool get isBound => _dataBound;
  bool get isNotBound => !isBound;

  WebSocket _socket;
  bool get isConnected => _socket?.isConnected == true;
  bool get isNotConnected => !isConnected;

  Future<void> setAccount(Account account) async {
    if(account?.uid != _account?.uid) {
      if(_account != null) {
        await _data?.destroy();
        _data = null;
      }
      _account = account;
      if(_account != null) {
        _data = await builder('$root/${_account.uid}/app');
        await _data.open();
        await _updateDataBinding();
      }
    }
  }

  Future<void> setSocket(WebSocket socket) async {
    _socket = socket;
    await _updateDataBinding();
  }

  Future<void> _updateDataBinding() async {
    if(isConnected) {
      final result = await _socket.get('/data/db/$name/open');
      print('result: $result');
      // if(_data.id == null) {
      //   await _data.reset(socket: _socket);
      // }
      print('client bind');
      await _data.bind(_socket);
      _dataBound = true;
    } else {
      await _data?.unbind(_socket);
      _dataBound = false;
    }
  }
}