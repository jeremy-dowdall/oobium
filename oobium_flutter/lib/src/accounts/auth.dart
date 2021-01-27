import 'dart:async';

import 'package:connectivity/connectivity.dart';
import 'package:flutter/material.dart';
import 'package:oobium/oobium.dart';
import 'package:oobium_routing/oobium_routing.dart';
import 'package:provider/provider.dart';

extension BuildContextAuthExt on BuildContext {
  Auth get auth => Provider.of<Auth>(this, listen: false);
}

enum AuthState {
  Unknown, Anonymous, SigningUp, SigningIn, SignedIn, SigningOut
}

class Auth {

  Future<String> requestInstallCode() => _appState.requestInstallCode();
  Future<void> signIn(String uid, String token) => _appState.signIn(uid, token);
  Future<void> signUp(String code) => _appState.signUp(code);
  Future<void> signOut() => _appState.signOut();

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

  _AuthenticatedAppState _appState;
  void _attach(_AuthenticatedAppState state) {
    _appState = state;
  }
  void _detach() {
    _appState = null;
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

class AuthRouterState extends AppRouterState {

  final Auth _auth;
  AuthRouterState(this._auth) {
    _auth.addListener(notifyListeners);
  }

  @override
  void dispose() {
    _auth.removeListener(notifyListeners);
    super.dispose();
  }

  AuthState get authState => _auth.state;

  bool get isAnonymous => _auth.isAnonymous;
  bool get isNotAnonymous => _auth.isNotAnonymous;

  bool get isSigningUp => _auth.isSigningUp;
  bool get isNotSigningUp => _auth.isNotSigningUp;

  bool get isSigningIn => _auth.isSigningIn;
  bool get isNotSigningIn => _auth.isNotSigningIn;

  bool get isSignedIn => _auth.isSignedIn;
  bool get isNotSignedIn => _auth.isNotSignedIn;

  bool get isSigningOut => _auth.isSigningOut;
  bool get isNotSigningOut => _auth.isNotSigningOut;
}

class AuthenticatedApp extends StatefulWidget {

  final auth = Auth();
  final Widget Function(BuildContext context, Auth auth) builder;
  final FutureOr<Database> Function(String path) data;
  final FutureOr<String> Function() root;
  AuthenticatedApp({@required this.builder, @required this.data, @required this.root});

  @override
  State<StatefulWidget> createState() => _AuthenticatedAppState();
}

class _AuthenticatedAppState extends State<AuthenticatedApp> {

  Future<String> requestInstallCode() async {
    if(widget.auth.isSignedIn && isConnected) {
      return _socket.newInstallToken();
    }
    return null;
  }

  Future<void> signIn(String uid, String token) async {
    widget.auth._setState(AuthState.SigningIn);
    final account = _accounts.getAll<Account>().firstWhere((_) => true, orElse: () => Account(uid: ''));
    _accounts.put(account.copyWith(uid: uid, token: token));
    await _onAccountChanged(uid, token);
    await _updateConnection();
  }

  Future<void> signUp(String code) async {
    widget.auth._setState(AuthState.SigningUp);
    try {
      _socket = await AuthSocket().connect(address: _address, port: _port, token: code);
      await signIn(_socket.uid, _socket.token);
    } catch(e) {
      widget.auth._setState(AuthState.Anonymous);
    }
  }

  Future<void> signOut() async {
    widget.auth._setState(AuthState.SigningOut);
    final account = _accounts.getAll<Account>().firstWhere((_) => true, orElse: () => null);
    _accounts.remove(account?.uid);
    await _onAccountChanged(null, null);
    await _updateConnection();
  }


  final _connectivity = Connectivity();

  ConnectivityResult _connectionStatus;
  StreamSubscription<ConnectivityResult> _connectivitySubscription;

  String _root;
  Database _accounts;

  @override
  void initState() {
    super.initState();
    Future.value(widget.root()).then((root) async {
      if(mounted) {
        _root = root;
        _accounts = AuthClientData('$_root/accounts');
        await _accounts.open();
        widget.auth._attach(this);
        await _initAccount();
        await _initConnectivity();
        _connectivitySubscription = _connectivity.onConnectivityChanged.listen(_onConnectivityChanged);
      }
    });
  }

  @override
  void dispose() {
    _widget = null;
    _data?.close();
    _accounts.close();
    widget.auth._detach();
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  Widget _widget;
  @override
  Widget build(BuildContext context) => MultiProvider(
    providers: [
      Provider<Auth>.value(value: widget.auth),
    ],
    builder: (context, _) => _widget ??= widget.builder(context, widget.auth),
  );

  Future<void> _initAccount() async {
    final account = _accounts.getAll<Account>().firstWhere((_) => true, orElse: () => null);
    _onAccountChanged(account?.uid, account?.token);
  }

  Future<void> _initConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      return _onConnectivityChanged(result);
    } catch (e) {
      print(e.toString());
      return _onConnectivityChanged(null);
    }
  }

  Future<void> _onAccountChanged(String uid, String token) async {
    print('_onAccountChanged($uid, $token)');
    _uid = uid;
    _token = token;
    await _updateAccount();
  }

  Future<void> _onConnectivityChanged(ConnectivityResult result) async {
    _connectionStatus = result;
    _updateConnection();
  }

  Future<void> _updateAccount() async {
    if(_uid != null && _token != null) {
      widget.auth._setState(AuthState.SigningIn);
      _data = await widget.data('$_root/$_uid/app');
      await _data.open();
      widget.auth._setState(AuthState.SignedIn);
    } else {
      if(widget.auth.isSignedIn) {
        widget.auth._setState(AuthState.SigningOut);
      }
      await _data?.destroy();
      _data = null;
      widget.auth._setState(AuthState.Anonymous);
    }
    await _updateConnection();
  }

  Future<void> _updateConnection() async {
    if(widget.auth.isSignedIn && canConnect) {
      if(isConnected) {
        return;
      } else {
        try {
          _socket ??= await AuthSocket().connect(address: _address, port: _port, uid: _uid, token: _token);
          _socket.done.then(_onSocketDone);
          await _socket.ready;
        } catch(e) {
          print(e);
          // fall through to make sure everything is closed and unbound
        }
      }
    } else {
      await _socket?.close();
      _socket = null;
    }
    await _updateDataBinding();
  }

  Future<void> _updateDataBinding() async {
    if(isConnected) {
      // if(_data.cannotBind) {
      //
      // }
      // await _data.bind(_socket);
      // _dataBound = true;
    } else {
      _data?.unbind(_socket);
      _dataBound = false;
    }
  }

  Database _data;
  bool _dataBound = false;
  bool get isBound => _dataBound;
  bool get isNotBound => !isBound;

  AuthSocket _socket;
  String _address;
  int _port;
  bool get canConnect => (_connectionStatus == ConnectivityResult.wifi) || (_connectionStatus == ConnectivityResult.mobile);
  bool get cannotConnect => !canConnect;
  bool get isConnected => _socket?.isConnected == true;
  bool get isNotConnected => !isConnected;


  String _uid;
  String _token;

  Future<void> _onSocketDone(event) async {
    _data?.unbind(_socket);
    _dataBound = false;
    _socket = null;
    if(canConnect) {
      print('reconnecting');
      return _updateConnection();
    } else {
      print('skipping reconnect: no network connection');
    }
  }
}
