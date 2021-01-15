import 'package:oobium/oobium.dart';
import 'package:oobium/src/clients/account.schema.gen.models.dart';

class AdminClient {

  final int port;
  AdminClient({this.port = 8001});

  Future<Account> createAccount(String name) async {
    final socket = await WebSocket().connect(address: '127.0.0.1', port: port, path: '/admin');
    try {
      final result = await socket.put('/account/new', {'name': name});
      if(result.isSuccess) {
        return Account.fromJson(result.data);
      } else {
        throw Exception('error: ${result.code}');
      }
    } finally {
      await socket.close();
    }
  }

  Future<Account> getAccount(String id) async {
    final socket = await WebSocket().connect(address: '127.0.0.1', port: port, path: '/admin');
    try {
      final result = await socket.get('/account/$id');
      if(result.isSuccess) {
        return Account.fromJson(result.data);
      } else {
        throw Exception('error: ${result.code}');
      }
    } finally {
      await socket.close();
    }
  }

  Future<Account> getAdmin({String id}) async {
    final socket = await WebSocket().connect(address: '127.0.0.1', port: port, path: '/admin');
    try {
      final result = await socket.get('/account');
      if(result.isSuccess) {
        return Account.fromJson(result.data);
      } else {
        throw Exception('error: ${result.code}');
      }
    } finally {
      await socket.close();
    }
  }
}