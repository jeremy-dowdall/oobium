import 'dart:async';

import 'package:oobium/src/clients/account.schema.gen.models.dart';
import 'package:oobium/src/clients/auth_socket.dart';
import 'package:oobium/src/database.dart';

enum AuthState {
  Unknown, Anonymous, SigningUp, SigningIn, SignedIn, SigningOut
}

enum ConnectionStatus {
  none, mobile, wifi
}

class Auth {

  Future<String> requestInstallCode() => _client.requestInstallCode();
  Future<void> signIn(String uid, String token) => _client.signIn(uid, token);
  Future<void> signUp(String code) => _client.signUp(code);
  Future<void> signOut() => _client.signOut();

  final _listeners = <Function>[];
  void addListener(Function listener) => _listeners.add(listener);
  bool removeListener(Function listener) => _listeners.remove(listener);

  AuthState _state = AuthState.Unknown;
  AuthState get state => _state;

  bool get isUnknown => _state == AuthState.Unknown;
  bool get isNotUnknown => !isUnknown;

  bool get isAnonymous => _state == AuthState.Anonymous;
  bool get isNotAnonymous => !isAnonymous;

  bool get isSigningUp => _state == AuthState.SigningUp;
  bool get isNotSigningUp => !isSigningUp;

  bool get isSigningIn => _state == AuthState.SigningIn;
  bool get isNotSigningIn => !isSigningIn;

  bool get isSignedIn => _state == AuthState.SignedIn;
  bool get isNotSignedIn => !isSignedIn;

  bool get isSigningOut => _state == AuthState.SigningOut;
  bool get isNotSigningOut => !isSigningOut;

  AuthClient _client;
  void _attach(AuthClient client) {
    _client = client;
  }
  void _detach() {
    _client = null;
  }

  void _setState(AuthState state) {
    print('setState($_state -> $state)');
    if(_state != state) {
      _state = state;
      for(var listener in _listeners.toList(growable: false)) {
        listener();
      }
    }
  }
}

class AuthClient {

  final Auth auth;
  final String address;
  final int port;
  final String root;
  final _accountListeners = <FutureOr<void> Function(Account account)>[];
  final _socketListeners = <FutureOr<void> Function(AuthSocket socket)>[];
  AuthClient({Auth auth, this.address='127.0.0.1', this.port=8001, this.root=''}) : auth = auth ?? Auth();

  Database _accounts;
  Account _account;

  AuthSocket _socket;
  ConnectionStatus _connectionStatus;
  bool get canConnect => (_connectionStatus == ConnectionStatus.wifi) || (_connectionStatus == ConnectionStatus.mobile);
  bool get cannotConnect => !canConnect;
  bool get isConnected => _socket?.isConnected == true;
  bool get isNotConnected => !isConnected;

  bool get isAttached => auth._client == this;
  bool get isNotAttached => !isAttached;

  void init() async {
    _accounts = AccountData(root);
    await _accounts.open();
    auth._attach(this);
    await _initAccount();
  }

  void dispose() async {
    await _accounts.close();
    auth._detach();
  }

  Future<void> bindAccount(FutureOr<void> Function(Account account) listener) {
    if(!_accountListeners.contains(listener)) {
      _accountListeners.add(listener);
      return listener(_account);
    }
    return Future.value();
  }
  
  Future<void> bindSocket(FutureOr<void> Function(AuthSocket socket) listener) {
    if(!_socketListeners.contains(listener)) {
      _socketListeners.add(listener);
      return listener(_socket);
    }
    return Future.value();
  }

  bool unbindAccount(FutureOr<void> Function(Account account) listener) {
    return _accountListeners.remove(listener);
  }

  bool unbindSocket(FutureOr<void> Function(AuthSocket socket) listener) {
    return _socketListeners.remove(listener);
  }

  Future<void> setConnectionStatus(ConnectionStatus status) {
    _connectionStatus = status;
    return _updateConnection();
  }

  Future<String> requestInstallCode() async {
    if(auth.isSignedIn && isConnected) {
      return _socket.newInstallToken();
    }
    return null;
  }

  Future<void> signIn(String uid, String token) async {
    auth._setState(AuthState.SigningIn);
    final current = _accounts.getAll<Account>().firstWhere((_) => true, orElse: () => Account());
    final update = _accounts.put(current.copyWith(uid: uid, token: token));
    await _onAccountChanged(update);
  }

  Future<void> signUp(String code) async {
    auth._setState(AuthState.SigningUp);
    try {
      _socket = await AuthSocket().connect(address: address, port: port, token: code);
      await signIn(_socket.uid, _socket.token);
    } catch(e) {
      auth._setState(AuthState.Anonymous);
    }
  }

  Future<void> signOut() async {
    auth._setState(AuthState.SigningOut);
    final account = _accounts.getAll<Account>().firstWhere((_) => true, orElse: () => null);
    _accounts.remove(account?.uid);
    await _onAccountChanged(null);
    await _updateConnection();
  }


  Future<void> _initAccount() async {
    final account = _accounts.getAll<Account>().firstWhere((_) => true, orElse: () => null);
    _onAccountChanged(account);
  }

  Future<void> _onAccountChanged(Account account) async {
    _account = account;
    await _updateAccount();
  }

  Future<void> _updateAccount() async {
    if(_account != null) {
      auth._setState(AuthState.SigningIn);
      await Future.forEach(_accountListeners, (l) => l(_account));
      auth._setState(AuthState.SignedIn);
    } else {
      if(auth.isSignedIn) {
        auth._setState(AuthState.SigningOut);
      }
      await Future.forEach(_accountListeners, (l) => l(null));
      auth._setState(AuthState.Anonymous);
    }
  }

  Future<void> _updateConnection() async {
    if(isAttached && canConnect && auth.isSignedIn) {
      if(isConnected) {
        return;
      } else {
        try {
          _socket = await AuthSocket().connect(address: address, port: port, uid: _account.uid, token: _account.token);
          _socket.done.then(_onSocketDone);
          await _socket.ready;
          await Future.forEach(_socketListeners, (l) => l(_socket));
        } catch(e) {
          print(e);
        }
      }
    } else {
      await _socket?.close();
      _socket = null;
      await Future.forEach(_socketListeners, (l) => l(null));
    }
  }

  Future<void> _onSocketDone(event) {
    print('onSocketDone');
    return _updateConnection();
  }
}
