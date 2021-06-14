import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:oobium/src/file_cache.dart';

abstract class ApiClient {

  final FileCache? cache;
  ApiClient(this.cache);

  Future<T> get<T>({required String path, required T Function(Map json) builder, force = false}) async {
    final data = await _get(path, force: force);
    final json = jsonDecode(data);
    return builder(json);
  }

  Future<List<T>> getAll<T>({required String path, required T Function(Map json) builder, force = false}) async {
    final data = await _get(path, force: force);
    final json = jsonDecode(data);
    assert(json is List, 'expected $path to return a List; instead received $json');
    if(json is List) {
      return json.map((e) => builder(e)).toList();
    } else {
      return [];
    }
  }

  String createUrl(String path);
  Map<String, String> createHeaders();

  Future<String> _get(String path, {force = false}) async {
    if(force || cache == null || cache!.isExpired(path)) {
      final url = createUrl(path);
      final headers = createHeaders();
      try {
        final response = await http.get(Uri.parse(url), headers: headers);
        if(response.statusCode == 200) {
          final data = response.body;
          await cache?.put(path, data, expiresIn: Duration(days: 1));
          return data;
        } else {
          await cache?.remove(path);
          throw Exception('error: ${response.statusCode}-${response.reasonPhrase}');
        }
      } catch(e, s) {
        print('could not get $url: $e\n$s');
        throw e;
      }
    } else {
      final data = await cache?.get(path);
      return data ?? '';
    }
  }
}
