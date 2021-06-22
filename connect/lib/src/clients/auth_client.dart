import 'dart:async';

import 'package:oobium_connect/src/clients/auth_socket.dart';
import 'package:oobium_websocket/oobium_websocket.dart';

class AuthClient {

  final String root;
  final String address;
  final int port;
  AuthClient({required this.root, this.address='127.0.0.1', this.port=8001});

  AuthClientData? _ds;
  Account? _account;
  AuthSocket? _socket;

  Account? get account => _account;
  Iterable<Account> get accounts => _ds?.getAccounts() ?? <Account>[];
  WebSocket? get socket => _socket;

  bool get isConnected => _socket?.isConnected == true;
  bool get isNotConnected => !isConnected;
  bool get isAnonymous => _account == null;
  bool get isNotAnonymous => !isAnonymous;
  bool get isSignedIn => _account != null;
  bool get isNotSignedIn => !isSignedIn;
  bool get isOpen => _ds != null;
  bool get isNotOpen => !isOpen;

  Future<AuthClient> open() async {
    if(isNotOpen) {
      _ds = await AuthClientData('$root/auth').open();
      if(_ds!.isNotEmpty) {
        _account = (accounts.toList()..sort((a,b) => a.lastOpenedAt - b.lastOpenedAt)).first;
        await _setAccount(account!);
      }
    }
    return this;
  }

  Future<void> close() async {
    if(isOpen) {
      await _setAccount(null);
      await _ds?.close();
      _ds = null;
    }
  }

  Future<String?> requestInstallCode(FutureOr<bool> Function() onApprove) async {
    if(isSignedIn && isConnected) {
      _socket!.onApprove = onApprove;
      return _socket!.newInstallToken();
    }
    return null;
  }

  Future<void> signUp(String code) async {
    final socket = await AuthSocket().connect(address: address, port: port, token: code);
    await signIn(socket.uid, socket.token);
    await _setSocket(socket);
  }

  Future<void> signIn(String uid, String token) async {
    final account = accounts
      .firstWhere((a) => a.uid == uid,
        orElse: () => Account(uid: uid)
      ).copyWith(token: token);
    await _setAccount(account);
  }

  Future<void> signOut() async {
    if(isSignedIn) {
      _ds?.remove(_account!);
      await _ds?.flush();
      await _setAccount(null);
    }
  }

  Future<void> connect() async {
    if(isNotConnected && isSignedIn) {
      final socket = await AuthSocket().connect(address: address, port: port, uid: _account!.uid, token: _account!.token);
      await _setSocket(socket);
    }
  }

  Future<void> disconnect() {
    return _setSocket(null);
  }

  void _onSocketDone(AuthSocket? socket) {
    print('_onSocketDone($socket)');
  }

  Future<void> _setAccount(Account? account) async {
    if(_account?.id != account?.id) {
      if(account != null) {
        _account = _ds?.put(account.copyWith(lastOpenedAt: DateTime.now().millisecondsSinceEpoch));
      } else {
        _account = null;
      }
      if(_socket?.uid != _account?.uid) {
        await disconnect();
      }
    }
  }

  Future<void> _setSocket(AuthSocket? socket) async {
    if(_socket != socket) {
      if(_socket != null) {
        await _socket?.close();
      }

      _socket = socket;

      if(_socket != null) {
        if(_account != null) {
          _account = _ds?.put(account!.copyWith(lastConnectedAt: DateTime.now().millisecondsSinceEpoch));
        }
        _socket!.done.then((_) => _onSocketDone(socket));
        await _socket!.ready;
      }
    }
  }
}
