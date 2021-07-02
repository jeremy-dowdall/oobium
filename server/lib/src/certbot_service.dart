import 'package:oobium_server/src/server.dart';
import 'package:oobium_server/src/service.dart';
import 'package:oobium_websocket/oobium_websocket.dart';

class OobiumService extends Service<Host, Null> {

  WebSocket? ws;

  @override
  Future<void> onAttach(Host host) async {
    ws = await WebSocket(host.name).connect(path: '/host');
    host.get('/.well-known/acme-challenge/<file>', [(req) async {
      return ws?.get('/acme-challenge/${req['file']}') ?? 404;
    }]);
  }

  @override
  Future<void> onDetach(Host host) async {
    await ws?.close();
    ws = null;
  }
}