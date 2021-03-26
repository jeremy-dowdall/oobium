import 'dart:io';
import 'dart:math';

import 'package:oobium/oobium.dart' hide User, Group, Membership;
import 'package:oobium_server/src/services/auth/validators.dart';
import 'package:oobium_server/src/services/auth_service.schema.gen.models.dart';
import 'package:oobium_server/src/server.dart';
import 'package:oobium_server/src/service.dart';

const WsProtocolHeader = 'sec-websocket-protocol';
const WsAuthProtocol = 'authorized';

Future<void> auth(Request req, Response res) => req.host.getService<AuthService>()._auth(req, res);

class AuthService extends Service<Host, AuthConnection> {

  final String root;
  final AuthServiceData _db;
  final _connections = <AuthConnection>[];
  final _validators = <AuthValidator>[];
  AuthService({this.root='test-data', Iterable<AuthValidator> validators}) : _db = AuthServiceData(root) {
    setValidators(validators ?? [AuthSocketValidator()]);
  }

  bool any(String id) => _db.any(id);
  bool none(String id) => _db.none(id);

  List<T> batch<T extends DataModel>({Iterable<T> put, Iterable<String> remove}) => _db.batch<T>(put: put, remove: remove);

  Group getGroup(String id) => _db.get<Group>(id);
  Iterable<Group> getGroups() => _db.getAll<Group>();
  Group putGroup(Group group) => _db.put(group);
  Group removeGroup(String id) => _db.remove(_db.get<Group>(id)?.id);

  Membership getMembership(String id) => _db.get<Membership>(id);
  Iterable<Membership> getMemberships() => _db.getAll<Membership>();
  Membership putMembership(Membership membership) => _db.put(membership);
  Membership removeMembership(String id) => _db.remove(_db.get<Membership>(id)?.id);

  User getUser(String id) => _db.get<User>(id);
  Iterable<User> getUsers() => _db.getAll<User>();
  User putUser(User user) => any(user.id) ? _db.put(user) : _db.put(user.copyWith(token: Token()));
  User removeUser(String id) => _db.remove(_db.get<User>(id)?.id);

  Link getLink(String id) => _db.get<Link>(id);
  Iterable<Link> getLinks() => _db.getAll<Link>();
  Link putLink(Link link) => any(link.id) ? _db.put(link) : _db.put(link);
  Link removeLink(String id) => _db.remove(_db.get<Link>(id)?.id);

  Token getToken(String id) => _db.get<Token>(id);
  Iterable<Token> getTokens() => _db.getAll<Token>();
  Token putToken(Token token) => any(token.id) ? _db.put(token) : _db.put(token);
  Token removeToken(String id) => _db.remove(_db.get<Token>(id)?.id);

  Stream<DataModelEvent> streamAll() => _db.streamAll();
  Stream<DataModelEvent<Group>> streamGroups({bool Function(Group model) where}) => _db.streamAll<Group>(where: where);
  Stream<DataModelEvent<Membership>> streamMemberships({bool Function(Membership model) where}) => _db.streamAll<Membership>(where: where);
  Stream<DataModelEvent<User>> streamUsers({bool Function(User model) where}) => _db.streamAll<User>(where: where);

  InstallCodes _codes;
  Token consume(String code) => removeToken(_codes.consume(code));

  String/*?*/ getUserToken(String uid, {bool forceNew = false}) {
    final user = _db.get<User>(uid);
    if(user != null) {
      final token = user.token;
      if(token == null) {
        final newToken = Token(user: user);
        _db.put(user.copyWith(token: newToken));
        return newToken.id;
      }
      if(forceNew || token.createdAt.isBefore(DateTime.now().subtract(Duration(days: 2)))) {
        final newToken = token.copyNew();
        _db.put(user.copyWith(token: newToken));
        return newToken.id;
      }
      return token.id;
    }
    return null;
  }

  User/*?*/ updateUserToken(String uid) {
    getUserToken(uid, forceNew: true);
    return _db.get<User>(uid);
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
    await _db.open();
    _codes = InstallCodes(_db);
    _startValidators();
  }

  @override
  Future<void> onStop() async {
    for(var connection in _connections) {
      await connection.close();
    }
    _connections.clear();
    await _db.close();
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
    _socket.on.get('/installs/token', (req, res) => res.send(code: 201, data: _service._codes.createInstallCode(uid)));
  }

  Future<void> close() => _socket.close();

  ServerWebSocket get socket => _socket;
  String get uid => _socket.uid;
}

abstract class AuthValidator {

  /*late*/ AuthService _service;
  AuthValidator();
  AuthValidator.values({AuthService service}) {
    _service = service;
  }

  Future<bool> validate(Request req);

  void onAttach(Host host) {}
  void onDetach(Host host) {}
  void onStart() {}
  void onStop() {}

  Token consume(String code) => _service.consume(code);

  Link getLink(bool Function(Link link) where) => _service.getLinks().firstWhere(where, orElse: () => null);
  Link putLink({String type, String code, Map<String, String> data}) =>  _service.putLink(Link(user: User(token: Token()), type: type, code: code, data: data));

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

  final Database _db;
  final _codes = <String, InstallCode>{};
  InstallCodes(this._db);

  String consume(String code) {
    return _codes.remove(code)?.token;
  }

  String createInstallCode(String userId) {
    final user = _db.get<User>(userId);
    final old = _codes.keys.firstWhere((k) => _codes[k].user == user.id, orElse: () => null);
    if(old != null) {
      print('found old code ($old), removing');
      _db.remove(_codes.remove(old).token);
    }

    final token = _db.put(Token(user: user));
    final code = _generateInstallCode();
    print('new code: $code');

    _codes[code] = InstallCode(user.id, token.id);
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
