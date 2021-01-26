import 'dart:async';

import 'package:meta/meta.dart';
import 'package:oobium/src/clients/auth_client.schema.gen.models.dart';
import 'package:oobium/src/clients/auth_socket.dart';
import 'package:oobium/src/websocket.dart';

class AuthClient {

  final String root;
  final String address;
  final int port;
  AuthClient({@required this.root, this.address='127.0.0.1', this.port=8001});

  AuthClientData _db;
  Account _account;
  AuthSocket _socket;

  Account get account => _account;
  Iterable<Account> get accounts => _db?.getAll<Account>() ?? <Account>[];  
  WebSocket get socket => _socket;

  bool get isConnected => _socket?.isConnected == true;
  bool get isNotConnected => !isConnected;
  bool get isAnonymous => _account == null;
  bool get isNotAnonymous => !isAnonymous;
  bool get isSignedIn => _account != null;
  bool get isNotSignedIn => !isSignedIn;
  bool get isOpen => _db != null;
  bool get isNotOpen => !isOpen;

  Future<AuthClient> open() async {
    if(isNotOpen) {
      _db = await AuthClientData('$root/auth').open();
      if(_db.isNotEmpty) {
        _account = (accounts.toList()..sort((a,b) => a.lastOpenedAt - b.lastOpenedAt)).first;
        _setAccount(account);
      }
    }
    return this;
  }

  Future<void> close() async {
    if(isOpen) {
      _setAccount(null);
      _setSocket(null);
      await _db.close();
      _db = null;
    }
  }

  Future<String> requestInstallCode() async {
    throw Exception('not yet implemented');
  }

  Future<void> signIn(String uid, String token) async {
    final account = accounts
      .firstWhere((a) => a.uid == uid,
        orElse: () => Account(uid: uid)
      ).copyWith(token: token);
    _setAccount(account);
  }

  Future<void> signUp(String code) async {
    throw Exception('not yet implemented');
  }

  Future<void> signOut() async {
    if(isSignedIn) {
      _db?.remove(_account.id);
      _setAccount(null);
    }
    if(isConnected) {
      final socket = _socket;
      _setSocket(null);
      await socket.close();
    }
  }

  Future<void> connect() async {
    if(isNotConnected && isSignedIn) {
      final socket = await AuthSocket().connect(address: address, port: port, uid: _account.uid, token: _account.token);
      socket.done.then((_) => _onSocketDone(socket));
      await socket.ready;
      _setSocket(socket);
    }
  }

  void _onSocketDone(AuthSocket socket) {
    print('_onSocketDone($socket)');
  }

  void _setAccount(Account account) {
    if(_account?.id != account?.id) {
      if(account != null) {
        account = _db.put(account.copyWith(lastOpenedAt: DateTime.now().millisecondsSinceEpoch));
      }
      _account = account;
    }
  }

  void _setSocket(AuthSocket socket) {
    if(_socket != socket) {
      _socket = socket;
      if(account != null) {
        _account = _db.put(account.copyWith(lastConnectedAt: DateTime.now().millisecondsSinceEpoch));
      }
    }
  }
}
