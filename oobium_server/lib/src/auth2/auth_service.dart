import 'dart:io';

import 'package:oobium/oobium.dart';
import 'package:oobium_server/src/auth2/auth.schema.gen.models.dart';
import 'package:oobium_server/src/server.dart';

const WsProtocolHeader = 'sec-websocket-protocol';
const WsAuthProtocol = 'authorized';

class AuthService {

  final AuthData _db;
  final _codes = <String, String>{};
  AuthService({String path = 'data/auth'}) : _db = AuthData(path);

  List<WsSubscription> _subscriptions;

  Future<void> init() async {
    await _db.open();
    final admin = _admin;
    print('AuthToken: ${admin.id}-${admin.token.id}');
  }

  void connect(Host host) {
    host.get('/auth', [_auth(host), websocket((socket) {
      _subscriptions = [
        socket.on.get('/users/id', onGetUserId(socket)),
        socket.on.get('/users/token', onGetUserToken(socket)),
        socket.on.get('/users/token/new', onGetUserToken(socket)),
        socket.on.get('/installs/token', onGetInstallToken(socket)),
      ];
    }, protocol: (_) => WsAuthProtocol)]);
    host.get('/auth/admin', [(req, res) {
      if(req.settings.address == '127.0.0.1') {
        final admin = _admin;
        return res.sendJson({'id': admin.id, 'token': admin.token.id});
      } else {
        return res.send(code: HttpStatus.forbidden);
      }
    }]);
  }

  void cancel() {
    if(_subscriptions != null) {
      for (var subscription in _subscriptions) {
        subscription.cancel();
      }
    }
  }

  User get _admin => _db.getAll<User>()
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
        } else {
          print('auth failed with token: $authToken');
        }
      } else {
        final code = authToken;
        final tokenId = _codes.remove(code);
        final token = _db.remove<Token>(tokenId);
        final approval = await host.socket(token?.user?.id)?.get('/installs/approval');
        if(approval?.isSuccess == true && approval.data == true) {
          final user = _db.put(User(token: token.copyNew(), referredBy: token.user));
          req['uid'] = user.id;
          return;
        } else {
          print('auth failed with code: $authToken');
        }
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
