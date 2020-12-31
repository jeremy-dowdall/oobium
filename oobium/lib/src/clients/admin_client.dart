import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:oobium/src/clients/account.schema.gen.models.dart';

class AdminClient {

  final int port;
  AdminClient({this.port = 8001});

  Future<Account> getAccount({String id}) async {
    final response = await http.get('http://127.0.0.1:$port/admin/account');
    if(response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return Account.fromJson(data);
    } else {
      throw Exception('error: ${response.statusCode}-${response.reasonPhrase}');
    }
  }
  
}