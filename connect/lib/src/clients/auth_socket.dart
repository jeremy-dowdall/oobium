import 'dart:async';

import 'package:oobium/src/websocket.dart';

class AuthSocket extends WebSocket {

  @override
  Future<AuthSocket> connect({String address='127.0.0.1', int port=8080, String? token, String? uid, List<String>? protocols, String path = '/auth', bool autoStart = true}) async {
    final authToken = (uid != null) ? '$uid-$token' : (token ?? '');
    protocols = ['authorized', authToken, ...?protocols];
    await super.connect(address: address, port: port, path: path, protocols: protocols, autoStart: autoStart);
    _uid = uid ?? (await get('/users/id')).data;
    _token = (await get('/users/token')).data;
    return this;
  }

  late String _uid;
  late String _token;
  String get uid => _uid;
  String get token => _token;

  Future<String?> newInstallToken() async {
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

  FutureOr<bool> Function()? _onApprove;
  WsSubscription? _onApproveSub;
  set onApprove(FutureOr<bool> Function() value) {
    _onApprove = value;
    _onApproveSub?.cancel();
    if(_onApprove != null) {
      _onApproveSub = on.get('/installs/approval', _onApproveInstall);
    }
  }

  Future<void> _onApproveInstall(WsRequest req, WsResponse res) async {
    assert(_onApprove != null, 'approval callback not set');
    final approved = await _onApprove?.call();
    res.send(data: approved);
  }
}
