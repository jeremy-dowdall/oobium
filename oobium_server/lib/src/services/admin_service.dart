import 'dart:io';

import 'package:oobium_server/src/services/auth_service.dart';
import 'package:oobium_server/src/services/services.dart';
import 'package:oobium_server/src/server.dart';

class AdminService extends Service<Host, Object> {

  @override
  void onAttach(Host host) {
    host.get('/admin', [_auth, websocket((socket) {
      socket.on.get('/account', (req, res) {
        final admin = services.get<AuthService>().getAdmin(orCreate: true);
        res.send(data: {'uid': admin.id, 'token': admin.token.id});
      });
      socket.on.get('/account/<id>', (req, res) {
        final user = services.get<AuthService>().getUser(req['id']);
        if(user != null) {
          res.send(data: {'uid': user.id, 'token': user.token.id});
        } else {
          res.send(code: 404);
        }
      });
      socket.on.put('/account/new', (req, res) {
        final user = services.get<AuthService>().createUser(req.data.value);
        res.send(data: {'uid': user.id, 'token': user.token.id});
      });
    })]);
  }

  Future<void> _auth(Request req, Response res) async {
    if(req.settings.address != '127.0.0.1') {
      return res.send(code: HttpStatus.forbidden);
    }
  }
}
