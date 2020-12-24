import 'dart:io';
import 'dart:math';

import 'package:oobium/oobium.dart';
import 'package:oobium_server/src/services/auth/auth.schema.gen.models.dart';
import 'package:oobium_server/src/services/services.dart';
import 'package:oobium_server/src/server.dart';

const WsProtocolHeader = 'sec-websocket-protocol';
const WsAuthProtocol = 'authorized';

class AuthService extends Service2<HostService> {

  final AuthData _db;
  final _codes = <String, InstallCode>{};
  AuthService({String path = 'data/auth'}) : _db = AuthData(path);

  ServerWebSocket _socket;
  ServerWebSocket get socket => _socket;

  @override
  void onAttach(HostService service) {
    final host = service.host;
    host.get('/auth', [_auth(host), websocket((socket) {
      _socket = socket;
      socket.on.get('/users/id', onGetUserId(socket));
      socket.on.get('/users/token', onGetUserToken(socket));
      socket.on.get('/users/token/new', onGetUserToken(socket));
      socket.on.get('/installs/token', onGetInstallToken(socket));
      services.attach();
      socket.done.then((_) => services.detach());
    }, protocol: (_) => WsAuthProtocol)]);
    // host.get('/auth/admin', [(req, res) {
    //   if(req.settings.address == '127.0.0.1') {
    //     final admin = _admin;
    //     return res.sendJson({'id': admin.id, 'token': admin.token.id});
    //   } else {
    //     return res.send(code: HttpStatus.forbidden);
    //   }
    // }]);
  }

  @override
  Future<void> onStart() async {
    await _db.open();
    final admin = this.admin;
    print('AuthToken: ${admin.id}-${admin.token.id}');
  }

  @override
  Future<void> onStop() async {
    return Future.wait([_socket?.close(), _db.close()]);
  }

  User get admin => _db.getAll<User>()
      .firstWhere((user) => user.role == 'admin',
      orElse: () => _db.put(User(name: 'admin', role: 'admin', token: Token())));

  RequestHandler _auth(Host host) => (Request req, Response res) async {
    final authToken = _authToken(req);
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
        final code = authToken;
        final tokenId = _codes.remove(code)?.token;
        if(tokenId != null) {
          final token = _db.remove<Token>(tokenId);
          final approval = await host.socket(token?.user?.id)?.get('/installs/approval');
          if(approval?.isSuccess == true && approval.data == true) {
            final user = _db.put(User(token: token.copyNew(), referredBy: token.user));
            req['uid'] = user.id;
            return;
          }
        }
        print('auth failed with code: $authToken');
      }
    }
    return res.send(code: HttpStatus.forbidden);
  };

  String _authToken(Request req) {
    final protocols = req.header[WsProtocolHeader]?.split(', ') ?? <String>[];
    if(protocols.length == 2 && protocols[0] == WsAuthProtocol) {
      return protocols[1];
    }
    return null;
  }

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

class InstallCode {
  final String user;
  final String token;
  InstallCode(this.user, this.token);
}