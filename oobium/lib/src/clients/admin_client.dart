import 'package:oobium/oobium.dart';

class AdminClient {

  final int port;
  AdminClient({this.port = 8001});

  Future<Map> createGroup(String name) => _put('/groups/new', {'name': name});
  Future<Map> getGroup(String id) => _get('/groups/$id');

  Future<Map> createMembership({@required String user, @required String group}) => _put('/memberships/new', {'user': user, 'group': group});
  Future<Map> getMembership(String id) => _get('/memberships/$id');

  Future<Map> createUser(String name) => _put('/users/new', {'name': name});
  Future<Map> getUser(String id) => _get('/users/$id');
  Future<Map> getAdmin() => _get('/users?role=admin');

  Future<Map> _get(String path) => _request('GET', path, null);
  Future<Map> _put(String path, data) => _request('PUT', path, data);

  Future<Map> _request(String method, String path, data) async {
    final socket = await WebSocket().connect(address: '127.0.0.1', port: port, path: '/admin');
    try {
      final result = await ((method == 'GET') ? socket.get(path) : socket.put(path, data));
      if(result.isSuccess) {
        return result.data as Map;
      } else {
        throw Exception('error: ${result.code}');
      }
    } finally {
      await socket.close();
    }
  }
}