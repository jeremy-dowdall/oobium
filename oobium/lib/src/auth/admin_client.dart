import 'dart:convert';

import 'package:http/http.dart' as http;

class Admin {
  final String id;
  final String token;
  Admin(this.id, this.token);
}

class AdminClient {

  static Future<Admin> getAdmin([int port = 8080]) async {
    final response = await http.get('http://127.0.0.1:$port/auth/admin');
    if(response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return Admin(data['id'], data['token']);
    } else {
      throw Exception('error: ${response.statusCode}-${response.reasonPhrase}');
    }
  }
  
}