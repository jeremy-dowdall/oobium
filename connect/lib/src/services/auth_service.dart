import 'dart:io';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:oobium_connect/src/services/auth/validators.dart';
import 'package:oobium_connect/src/services/auth_service.schema.g.dart';
import 'package:oobium_server/src/server.dart';
import 'package:oobium_server/src/service.dart';

const WsProtocolHeader = 'sec-websocket-protocol';
const WsAuthProtocol = 'authorized';

Future<void> auth(Request req, Response res) => req.host.getService<AuthService>()._auth(req, res);

class AuthService extends Service<Host, AuthConnection> {

  final String root;
  final AuthServiceData _ds;
  final _connections = <AuthConnection>[];
  final _validators = <AuthValidator>[];
  AuthService({this.root='test-data', Iterable<AuthValidator>? validators}) : _ds = AuthServiceData(root) {
    setValidators(validators ?? [AuthSocketValidator()]);
  }

  InstallCodes? _codes;
  AuthToken? consume(String code) => _ds.remove(_codes?.consume(code));

  String? getUserToken(String uid, {bool forceNew = false}) {
    final user = _ds.get<User>(uid);
    if(user != null) {
      final token = user.token;
      if(token == null) {
        final newToken = Token(user: user);
        _ds.put(user.copyWith(token: newToken));
        return newToken.id;
      }
      if(forceNew || token.createdAt.isBefore(DateTime.now().subtract(Duration(days: 2)))) {
        final newToken = token.copyNew();
        _ds.put(user.copyWith(token: newToken));
        return newToken.id;
      }
      return token.id;
    }
    return null;
  }

  User? updateUserToken(String uid) {
    getUserToken(uid, forceNew: true);
    return _ds.get<User>(uid);
  }

  @override
  void onAttach(Host host) {
    host.get('/auth', [_auth, websocket((socket) async {
      final connection = AuthConnection._(this, socket);
      _connections.add(connection);
      await services.attach(connection);
      // ignore: unawaited_futures
      socket.done.then((_) {
        _connections.remove(connection);
        services.detach(connection);
      });
    }, protocol: (_) => WsAuthProtocol)]);
    for(var validator in _validators) {
      validator.onAttach(host);
    }
  }

  @override
  void onDetach(Host host) {
    for(var connection in _connections) {
      connection.close();
    }
    _connections.clear();
    for(var validator in _validators) {
      validator.onDetach(host);
    }
  }

  @override
  Future<void> onStart() async {
    await _ds.open();
    _codes = InstallCodes(_ds);
    _startValidators();
  }

  @override
  Future<void> onStop() async {
    for(var connection in _connections) {
      await connection.close();
    }
    _connections.clear();
    await _ds.close();
    _codes = null;
    _stopValidators();
  }

  void addValidator(AuthValidator validator) {
    if(!_validators.contains(validator)) {
      validator._service = this;
      _validators.add(validator);
    }
  }

  void setValidators(Iterable<AuthValidator> validators) {
    _validators.clear();
    for(var validator in validators) {
      addValidator(validator);
    }
  }

  void _startValidators() {
    for(var validator in _validators) {
      validator.onStart();
    }
  }

  void _stopValidators() {
    for(var validator in _validators) {
      validator.onStop();
    }
  }

  Future<void> _auth(Request req, Response res) async {
    if(_validators.isEmpty) {
      return;
    }
    for(var validator in _validators) {
      if(await validator.validate(req)) {
        return;
      }
    }
    return res.send(code: HttpStatus.forbidden);
  }
}

class AuthConnection {

  final AuthService _service;
  final ServerWebSocket _socket;
  AuthConnection._(this._service, this._socket) {
    _socket.on.get('/users/id', (req, res) => res.send(data: uid));
    _socket.on.get('/users/token', (req, res) => res.send(data: _service.getUserToken(uid)));
    _socket.on.get('/users/token/new', (req, res) => res.send(data: _service.getUserToken(uid, forceNew: true)));
    _socket.on.get('/installs/token', (req, res) => res.send(code: 201, data: _service._codes?.createInstallCode(uid)));
  }

  Future<void> close() => _socket.close();

  ServerWebSocket get socket => _socket;
  String get uid => _socket.uid;
}

abstract class AuthValidator {

  late AuthService _service;
  AuthValidator();
  AuthValidator.values({required AuthService service}) {
    _service = service;
  }

  Future<bool> validate(Request req);

  void onAttach(Host host) {}
  void onDetach(Host host) {}
  void onStart() {}
  void onStop() {}

  Token? consume(String code) => _service.consume(code);

  bool hasUser(String userId, String tokenId) => _service.getUserToken(userId) == tokenId;
  User putUser(Token token) => _service.putUser(User(token: token.copyNew(), referredBy: token.user));

  void updateUserToken(String userId) {
    _service.updateUserToken(userId);
  }
}

class InstallCode {
  final String user;
  final String token;
  InstallCode(this.user, this.token);
}

class InstallCodes {

  final DataStore _ds;
  final _codes = <String, InstallCode>{};
  InstallCodes(this._ds);

  String? consume(String code) {
    return _codes.remove(code)?.token;
  }

  String createInstallCode(String userId) {
    final user = _ds.get<User>(userId);
    final old = _codes.keys.firstWhereOrNull((k) => _codes[k]?.user == user?.id);
    if(old != null) {
      print('found old code ($old), removing');
      _ds.remove(_codes.remove(old)?.token);
    }

    final token = _ds.put(Token(user: user));
    final code = _generateInstallCode();
    print('new code: $code');

    _codes[code] = InstallCode(user!.id, token.id);
    return code;
  }

  String _generateInstallCode() {
    final prng = Random();
    final digits = <String>[];
    for(var i = 0; i < 6; i++) {
      digits.add(prng.nextInt(10).toString());
    }
    return digits.join();
  }
}
