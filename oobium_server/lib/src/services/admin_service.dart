import 'dart:io';

import 'package:oobium_server/oobium_server.dart';
import 'package:oobium_server/src/services/services.dart';
import 'package:oobium_server/src/server.dart';

class AdminService extends Service2<HostService> {

  @override
  void onAttach(HostService service) {
    final host = service.host;
    host.get('/admin/auth', [_auth, (req, res) {
      final admin = services.get<AuthService>().admin;
      return res.sendJson({'id': admin.id, 'token': admin.token.id});
    }]);
  }

  Future<void> _auth(Request req, Response res) async {
    if(req.settings.address != '127.0.0.1') {
      return res.send(code: HttpStatus.forbidden);
    }
  }
}
