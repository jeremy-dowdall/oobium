import 'dart:convert' show jsonDecode, jsonEncode;
import 'package:oobium/src/string.extensions.dart';

abstract class Json implements JsonString {

  static decode(String json) => jsonDecode(json);
  static String encode(data) => jsonEncode(Json.from(data, full: true));

  const Json();

  Map<String, dynamic> toJson();
  
  @override
  String toJsonString() => jsonEncode(toJson());
  

  static List<T> convertToList<T>(data, T builder(key, value)) {
    if(data is Map) {
      return data.entries.map((entry) => builder(entry.key, entry.value)).toList();
    }
    return <T>[];
  }

  static V value<V>(data, String field) => (data is Map && (data[field] is V)) ? (data[field] as V) : null;

  static T field<T,V>(data, String field, [T builder(V value)]) {
    return (builder != null) ? builder(value<V>(data, field)) : value<V>(data, field);
  }

  static String string(data, String field) => Json.field<String, String>(data, field);

  static bool has(data, String field) => (data is Map && data[field] != null);

  static List<String> keys(data) {
    return (data is Map) ? data.keys.map((k) => k.toString()).toList() : [];
  }

  static T toOption<T>(data, String field, List<T> options) {
    final option = Json.field(data, field)?.toString();
    return (option != null) ? options.firstWhere((test) => test.toString() == option) : null;
  }

  static DateTime toDateTime(data, String field, [DateTime builder(v)]) {
    if(data is Map) {
      var value = data[field];
      if(value is String) {
        value = DateTime.parse(value).millisecondsSinceEpoch;
      }
      if(value is num) {
        final dt = DateTime.fromMillisecondsSinceEpoch(value.toInt());
        if(field == 'date' || field.endsWith('Date') || field.endsWith('On')) {
          return DateTime(dt.year, dt.month, dt.day);
        }
        if(field == 'time' || field.endsWith('Time') || field.endsWith('At')) {
          return DateTime(0, 0, 0, dt.hour, dt.minute, dt.second);
        }
        return dt;
      }
      return builder?.call(value);
    }
    return builder?.call(null);
  }

  static List<T> toList<T>(data, String field, T builder(element)) {
    if(!(data is Map) || !(data[field] is List)) return <T>[];
    return (data[field] as List).map((element) => builder(element)).toList();
  }

  static Map<String, T> toMap<T>(data, String field, T builder(value)) {
    Map<String, T> map = Map<String, T>();
    if((data is Map) && (data[field] is Map)) {
      (data[field] as Map).entries.forEach((MapEntry entry) {
        map[entry.key.toString()] = builder(entry.value);
      });
    }
    return map;
  }

  static Set<String> toSet(data, String field, [bool filter(value)]) {
    if(data is Map && data[field] is Iterable) {
      if(filter != null) {
        return data[field].where((e) => filter(e)).map((e) => e.toString()).cast<String>().toSet();
      } else {
        return data[field].map((e) => e.toString()).cast<String>().toSet();
      }
    }
    if(data is Map && data[field] is Map) {
      if(filter != null) {
        return data[field].keys.where((k) => filter(data[field][k])).map((k) => k.toString()).cast<String>().toSet();
      } else {
        return data[field].keys.map((k) => k.toString()).cast<String>().toSet();
      }
    }
    return Set<String>();
  }

  static List<String> toStrings(data, String field) => toList(data, field, (e) => e.toString());

  static from(field, {bool full}) {
    if(field == null) return null;
    if(field is JsonModel && full != true) return field.id;
    if(field is Json) return field.toJson();
    if(field is Map)  return fromMap(field);
    if(field is Iterable) return fromIterable(field, full: full);
    if(field is Set)  return fromSet(field);
    if(field is String || field is num || field is bool) return field;
    if(field is JsonString) return field.toJsonString();
    if(field is DateTime) return field.millisecondsSinceEpoch;
    if(field is Type) return field.toString();
    final value = _fromEnum(field);
    if(value != null) return value;
    throw "don't know how to convert $field to JSON";
  }

  static List<dynamic> fromIterable(Iterable iter, {bool full}) => iter?.map((e) => from(e, full: full))?.toList() ?? [];
  static List<dynamic> fromList(List list) => list?.map((e) => from(e))?.toList() ?? [];

  static Map<String, dynamic> fromMap(Map items) {
    final map = Map<String, dynamic>();
    items.entries.forEach((MapEntry entry) {
      map[entry.key.toString()] = from(entry.value);
    });
    return map;
  }

  static Map<String, dynamic> fromSet(Set set) => { for(var id in set ?? {}) id: true };

  static String _fromEnum(data) {
    final split = data.toString().split('.');
    return (split.length > 1 && split[0] == data.runtimeType.toString()) ? split[1] : null;
  }
}

abstract class JsonModel extends Json {

  final String id;
  const JsonModel(String id) : id = id ?? '';
  JsonModel.fromJson(data) : id = Json.field(data, 'id') ?? '';

  @override
  Map<String, dynamic> toJson() => Map<String, dynamic>()
    ..['id'] = Json.from(id)
  ;

  bool get isNew => id == null || id.isBlank;
  bool get isNotNew => !isNew;

  bool isSameAs(other) => !isNotSameAs(other);
  bool isNotSameAs(other) {
    if(runtimeType == other?.runtimeType && id == other?.uid) {
      final json1 = toJson(), json2 = other.toJson();
      return json1.keys.any((k) => json1[k] != json2[k]);
    }
    return true;
  }
}

abstract class JsonString {
  String toJsonString();
}

extension ListJsonExt on List { String toJson() => (this != null) ? jsonEncode(this) : '[]'; }
extension ListMapExt on Map { String toJson() => (this != null) ? jsonEncode(this) : '{}'; }