import 'dart:async';
import 'dart:io';

import 'package:oobium_connect/src/clients/user_client.schema.g.dart';
import 'package:oobium_connect/src/services/auth_service.dart';
import 'package:oobium_server/oobium_server.dart';

class AdminService extends Service<Host, Object> {

  @override
  void onAttach(Host host) {
    host.get('/admin', [_auth, websocket((socket) {

      socket.on.get('/groups', (req) {
        services.get<AuthService>().getGroups();
      });
      socket.on.get('/groups/<id>', (req) {
        final group = services.get<AuthService>().getGroup(req['id']);
        return Response(code: (group != null) ? 200 : 404, data: group);
      });
      socket.on.put('/groups/<id>', (req) {
        if(req.data.value == null) {
          final group = services.get<AuthService>().removeGroup(req['id']);
          return Response(code: (group != null) ? 200 : 404, data: group);
        } else {
          final group = services.get<AuthService>().putGroup(Group.fromJson(req.data.value, newId: (req['id'] == 'new')));
          return Response(code: (group != null) ? 200 : 400, data: group);
        }
      });

      socket.on.get('/memberships', (req) {
        return services.get<AuthService>().getMemberships();
      });
      socket.on.get('/memberships/<id>', (req) {
        final membership = services.get<AuthService>().getMembership(req['id']);
        return Response(code: (membership != null) ? 200 : 404, data: membership);
      });
      socket.on.put('/memberships/<id>', (req) {
        if(req.data.value == null) {
          final membership = services.get<AuthService>().removeMembership(req['id']);
          return Response(code: (membership != null) ? 200 : 404, data: membership);
        } else {
          final membership = services.get<AuthService>().putMembership(Membership.fromJson(req.data.value, newId: (req['id'] == 'new')));
          return Response(code: (membership != null) ? 200 : 400, data: membership);
        }
      });

      socket.on.get('/users', (req) {
        return services.get<AuthService>().getUsers();
      });
      socket.on.get('/users/<id>', (req) {
        final user = services.get<AuthService>().getUser(req['id']);
        return Response(code: (user != null) ? 200 : 404, data: user);
      });
      socket.on.put('/users/<id>', (req) {
        if(req.data.value == null) {
          final user = services.get<AuthService>().removeUser(req['id']);
          return Response(code: (user != null) ? 200 : 404, data: user);
        } else {
          final user = services.get<AuthService>().putUser(User.fromJson(req.data.value, newId: (req['id'] == 'new')));
          return Response(code: (user != null) ? 200 : 400, data: user);
        }
      });
    })]);
  }

  FutureOr<dynamic> _auth(Request req) async {
    if(req.host.settings.address != '127.0.0.1') {
      return HttpStatus.forbidden;
    }
  }
}
