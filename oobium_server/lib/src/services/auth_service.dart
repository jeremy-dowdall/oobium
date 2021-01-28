import 'dart:io';
import 'dart:math';

import 'package:oobium/oobium.dart' hide User, Group, Membership;
import 'package:oobium_server/src/services/auth_service.schema.gen.models.dart';
import 'package:oobium_server/src/server.dart';
import 'package:oobium_server/src/service.dart';

const WsProtocolHeader = 'sec-websocket-protocol';
const WsAuthProtocol = 'authorized';

class AuthConnection {

  final Database _db;
  final InstallCodes _codes;
  final ServerWebSocket _socket;
  AuthConnection._(this._db, this._codes, this._socket) {
    _socket.on.get('/users/id', (req, res) => res.send(data: uid));
    _socket.on.get('/users/token', (req, res) => res.send(data: getUserToken()));
    _socket.on.get('/users/token/new', (req, res) => res.send(data: getUserToken(forceNew: true)));
    _socket.on.get('/installs/token', (req, res) => res.send(code: 201, data: _codes.createInstallCode(uid)));
  }

  Future<void> close() => _socket.close();

  ServerWebSocket get socket => _socket;
  String get uid => _socket.uid;

  String getUserToken({bool forceNew = false}) {
    final user = _db.get<User>(uid);
    final token = user.token;
    if(forceNew || token.createdAt.isBefore(DateTime.now().subtract(Duration(days: 2)))) {
      final newToken = token.copyNew();
      _db.put(user.copyWith(token: newToken));
      return newToken.id;
    } else {
      return token.id;
    }
  }
}

class AuthService extends Service<Host, AuthConnection> {
  
  final String root;
  final AuthServiceData _db;
  final _connections = <AuthConnection>[];
  AuthService({this.root}) : _db = AuthServiceData(root);

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

  Stream<DataModelEvent> streamAll() => _db.streamAll();
  Stream<DataModelEvent<Group>> streamGroups({bool Function(Group model) where}) => _db.streamAll<Group>(where: where);
  Stream<DataModelEvent<Membership>> streamMemberships({bool Function(Membership model) where}) => _db.streamAll<Membership>(where: where);
  Stream<DataModelEvent<User>> streamUsers({bool Function(User model) where}) => _db.streamAll<User>(where: where);

  InstallCodes _codes;

  @override
  void onAttach(Host host) {
    host.get('/auth', [_auth(host), websocket((socket) async {
      final connection = AuthConnection._(_db, _codes, socket);
      _connections.add(connection);
      await services.attach(connection);
      // ignore: unawaited_futures
      socket.done.then((_) {
        _connections.remove(connection);
        services.detach(connection);
      });
    }, protocol: (_) => WsAuthProtocol)]);
  }

  @override
  void onDetach(Host host) {
    for(var connection in _connections) {
      connection.close();
    }
    _connections.clear();
  }

  @override
  Future<void> onStart() async {
    await _db.open();
    _codes = InstallCodes(_db);
  }

  @override
  Future<void> onStop() async {
    for(var connection in _connections) {
      await connection.close();
    }
    _connections.clear();
    await _db.close();
    _codes = null;
  }

  RequestHandler _auth(Host host) => (Request req, Response res) async {
    final authToken = _parseAuthToken(req);
    if(authToken is String) {
      if(authToken.contains('-')) {
        final sa = authToken.split('-');
        final uid = sa[0];
        final token = sa[1];
        if(_db.get<User>(uid)?.token?.id == token) {
          req['uid'] = uid;
          return;
        }
        print('auth failed with token: $authToken');
      } else {
        final tokenId = _codes.consume(authToken);
        if(tokenId != null) {
          final token = _db.remove<Token>(tokenId);
          final approval = await host.socket(token?.user?.id)?.getAny('/installs/approval');
          if(approval?.isSuccess == true && approval.data == true) {
            final user = _db.put(User(token: token.copyNew(), referredBy: token.user));
            req['uid'] = user.id;
            return;
          } else {
            print('auth failed on approval of code: $authToken');
          }
        } else {
          print('auth failed with code: $authToken');
        }
      }
    }
    return res.send(code: HttpStatus.forbidden);
  };

  String _parseAuthToken(Request req) {
    final protocols = req.header[WsProtocolHeader]?.split(', ') ?? <String>[];
    if(protocols.length == 2 && protocols[0] == WsAuthProtocol) {
      return protocols[1];
    }
    return null;
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