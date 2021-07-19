class Adapter<T> {

  final T Function(Map<String, dynamic> data) decode;
  final dynamic Function(String key, dynamic value) encode;
  final List<String> fields;

  Adapter({
    required this.decode,
    required this.encode,
    required this.fields,
  });

  // T fromJson(Map<String, dynamic> data);
  // Map<String, dynamic> toJson(T object);
}