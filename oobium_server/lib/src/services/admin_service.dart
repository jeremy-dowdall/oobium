import 'dart:io';

import 'package:oobium_server/src/services/auth_service.dart';
import 'package:oobium_server/src/service.dart';
import 'package:oobium_server/src/server.dart';
import 'package:oobium_server/src/services/auth_service.schema.gen.models.dart';

class AdminService extends Service<Host, Object> {

  @override
  void onAttach(Host host) {
    host.get('/admin', [_auth, websocket((socket) {

      socket.on.get('/groups', (req, res) {
        res.send(data: services.get<AuthService>().getGroups());
      });
      socket.on.get('/groups/<id>', (req, res) {
        final group = services.get<AuthService>().getGroup(req['id']);
        res.send(code: (group != null) ? 200 : 404, data: group);
      });
      socket.on.put('/groups/<id>', (req, res) {
        if(req.data.value == null) {
          final group = services.get<AuthService>().removeGroup(req['id']);
          res.send(code: (group != null) ? 200 : 404, data: group);
        } else {
          final group = services.get<AuthService>().putGroup(Group.fromJson(req.data.value, newId: (req['id'] == 'new')));
          res.send(code: (group != null) ? 200 : 400, data: group);
        }
      });

      socket.on.get('/memberships', (req, res) {
        res.send(data: services.get<AuthService>().getMemberships());
      });
      socket.on.get('/memberships/<id>', (req, res) {
        final membership = services.get<AuthService>().getMembership(req['id']);
        res.send(code: (membership != null) ? 200 : 404, data: membership);
      });
      socket.on.put('/memberships/<id>', (req, res) {
        if(req.data.value == null) {
          final membership = services.get<AuthService>().removeMembership(req['id']);
          res.send(code: (membership != null) ? 200 : 404, data: membership);
        } else {
          final membership = services.get<AuthService>().putMembership(Membership.fromJson(req.data.value, newId: (req['id'] == 'new')));
          res.send(code: (membership != null) ? 200 : 400, data: membership);
        }
      });

      socket.on.get('/users', (req, res) {
        res.send(data: services.get<AuthService>().getUsers());
      });
      socket.on.get('/users/<id>', (req, res) {
        final user = services.get<AuthService>().getUser(req['id']);
        res.send(code: (user != null) ? 200 : 404, data: user);
      });
      socket.on.put('/users/<id>', (req, res) {
        if(req.data.value == null) {
          final user = services.get<AuthService>().removeUser(req['id']);
          res.send(code: (user != null) ? 200 : 404, data: user);
        } else {
          final user = services.get<AuthService>().putUser(User.fromJson(req.data.value, newId: (req['id'] == 'new')));
          res.send(code: (user != null) ? 200 : 400, data: user);
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
