import 'dart:io';

import 'package:oobium_server/src/services/auth_service.dart';
import 'package:oobium_server/src/services/services.dart';
import 'package:oobium_server/src/server.dart';

class AdminService extends Service<HostService> {

  @override
  void onAttach(HostService service) {
    final host = service.host;
    host.get('/admin/account', [_auth, (req, res) {
      final admin = services.get<AuthService>().admin;
      return res.sendJson({'uid': admin.id, 'token': admin.token.id});
    }]);
  }

  Future<void> _auth(Request req, Response res) async {
    if(req.settings.address != '127.0.0.1') {
      return res.send(code: HttpStatus.forbidden);
    }
  }
}
