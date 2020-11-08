import 'dart:io';

import 'package:oobium_common/oobium_common.dart';
import 'package:oobium_server/src/auth2/auth.schema.gen.models.dart';
import 'package:oobium_server/src/server.dart';

class AuthServer {

  final Server _server;
  final Database _db;
  final _codes = <String, String>{};
  AuthServer({String address, int port, String dbPath}) :
        _server = Server(address: address ?? '127.0.0.1', port: port ?? 8001),
        _db = AuthData(dbPath ?? 'auth.db');

  Future<void> start() async {
    await _db.open();
    final admin = _db.getAll<User>()
        .firstWhere((user) => user.role == 'admin',
        orElse: () => _db.put(User(name: 'admin', role: 'admin', token: Token())));
    print('TOKEN ${admin.id}:${admin.token.id}');

    final host = _server.host();
    host.get('/auth', [_auth(host), websocket((socket) {
      socket.on.get('/users/id', onGetUserId(socket));
      socket.on.get('/users/token', onGetUserToken(socket));
      socket.on.get('/users/token/new', onGetUserToken(socket));
      socket.on.get('/installs/token', onGetInstallToken(socket));
    })]);
    await _server.start();
  }

  Future<void> stop() async {
    await _server.stop();
    await _db.close();
  }

  RequestHandler _auth(Host host) => (Request req, Response res) async {
    final authHeader = req.header[HttpHeaders.authorizationHeader];
    if(authHeader is String && authHeader.startsWith('TOKEN ')) {
      if(authHeader.contains(':', 6)) {
        final sa = authHeader.substring(6).split(':');
        final uid = sa[0];
        final token = sa[1];
        if(_db.get<User>(uid)?.token?.id == token) {
          req['uid'] = uid;
          return;
        } else {
          print('auth failed with token: $token');
        }
      } else {
        final code = authHeader.substring(6);
        final tokenId = _codes.remove(code);
        final token = _db.remove<Token>(tokenId);
        final approval = await host.socket(token?.user?.id)?.get('/installs/approval');
        if(approval?.isSuccess == true && approval.data == true) {
          final user = _db.put(User(token: token.copyNew(), referredBy: token.user));
          req['uid'] = user.id;
          return;
        } else {
          print('auth failed with code: $code');
        }
      }
    }
    return res.send(code: HttpStatus.forbidden);
  };

  WsMessageHandler onGetUserId(ServerWebSocket socket) => (WsRequest req, WsResponse res) {
    res.send(data: _db.get<User>(socket.id).id);
  };

  WsMessageHandler onGetUserToken(ServerWebSocket socket,{bool forceNew = false}) => (WsRequest req, WsResponse res) {
    final user = _db.get<User>(socket.id);
    final token = user.token;
    if(forceNew || token.createdAt.isBefore(DateTime.now().subtract(Duration(days: 2)))) {
      final newToken = token.copyNew();
      _db.put(user.copyWith(token: newToken));
      res.send(data: newToken.id);
    } else {
      res.send(data: token.id);
    }
  };

  WsMessageHandler onGetInstallToken(ServerWebSocket socket) => (WsRequest req, WsResponse res) {
    final user = _db.get<User>(socket.id);
    final code = _createInstallCode(user);
    res.send(code: 201, data: code);
  };

  String _createInstallCode(User user) {
    final token = _db.put(Token(user: user));
    final code = token.id.substring(18);
    _codes[code] = token.id;
    for(var e in _codes.entries.toList(growable: false)) {
      // only allow one active install code per user
      if(e.key != code && _db.get<Token>(e.value)?.user?.id == user.id) {
        _codes.remove(e.key);
        _db.remove(e.value);
      }
    }
    return code;
  }
}
