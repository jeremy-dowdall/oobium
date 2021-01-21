import 'dart:io';

import 'package:oobium_server/src/services/auth_service.dart';
import 'package:oobium_server/src/services/services.dart';
import 'package:oobium_server/src/server.dart';

class AdminService extends Service<Host, Object> {

  @override
  void onAttach(Host host) {
    host.get('/admin', [_auth, websocket((socket) {

      socket.on.get('/groups/<id>', (req, res) {
        final group = services.get<AuthService>().getGroup(req['id']);
        if(group != null) {
          res.send(data: group);
        } else {
          res.send(code: 404);
        }
      });
      socket.on.put('/groups/new', (req, res) {
        final group = services.get<AuthService>().createGroup(req.data.value);
        res.send(data: group);
      });

      socket.on.get('/memberships/<id>', (req, res) {
        final membership = services.get<AuthService>().getMembership(req['id']);
        if(membership != null) {
          res.send(data: membership);
        } else {
          res.send(code: 404);
        }
      });
      socket.on.put('/memberships/new', (req, res) {
        final membership = services.get<AuthService>().createMembership(req.data.value);
        res.send(data: membership);
      });

      socket.on.put('/users/new', (req, res) {
        final user = services.get<AuthService>().createUser(req.data.value);
        res.send(data: user);
      });
      socket.on.get('/users/<id>', (req, res) {
        final user = services.get<AuthService>().getUser(req['id']);
        if(user != null) {
          res.send(data: user);
        } else {
          res.send(code: 404);
        }
      });
    })]);
  }

  Future<void> _auth(Request req, Response res) async {
    if(req.settings.address != '127.0.0.1') {
      return res.send(code: HttpStatus.forbidden);
    }
  }
}
