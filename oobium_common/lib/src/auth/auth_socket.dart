import 'dart:io' if (dart.library.html) 'dart:html' as ws;
import 'package:oobium_common/src/websocket/ws_socket.dart';
import 'package:oobium_common/src/websocket.dart';

class AuthSocket extends WebSocket {

  AuthSocket(WsSocket ws) : super(ws);

  static Future<AuthSocket> connect({String address, int port, String uid, String token}) async {
    final authToken = (uid != null) ? '$uid:$token' : token;
    assert(authToken != null);
    final url = 'ws://${address ?? '127.0.0.1'}:${port ?? 8080}/auth';
    final websocket = await WsSocket.connect(url, authToken);
    final socket = AuthSocket(websocket)..start();
    socket._uid ??= (await socket.get('/users/id')).data;
    socket._token = (await socket.get('/users/token')).data;
    return socket;
  }

  bool get isConnected => isNotDone;
  bool get isNotConnected => !isConnected;

  String _uid;
  String _token;
  String get uid => _uid;
  String get token => _token;

  Future<String> newInstallToken() async {
    assert(isConnected, 'cannot create install code when not connected');
    final result = await get('/installs/token');
    if(result.isSuccess) {
      return result.data;
    } else {
      print('error: ${result.code}-${result.data}');
      return null;
    }
  }

  Future<void> refreshToken({bool forceNew = false}) async {
    if(forceNew) {
      _token = (await get('/users/token/new')).data;
    } else {
      _token = (await get('/users/token')).data;
    }
  }

  Future<bool> Function() _onApprove;
  WsSubscription _onApproveSub;
  set onApprove(Future<bool> Function() value) {
    _onApprove = value;
    _onApproveSub?.cancel();
    if(_onApprove != null) {
      _onApproveSub = on.get('/installs/approval', _onApproveInstall);
    }
  }

  Future<void> _onApproveInstall(WsRequest req, WsResponse res) async {
    assert(_onApprove != null, 'approval callback not set');
    final approved = await _onApprove();
    res.send(data: approved);
  }
}
