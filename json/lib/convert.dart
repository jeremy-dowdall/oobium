
// TODO where does this class live?

extension ConvertMapX on Map? {

  DateTime? getDateTime(String field) {
    return decodeDateTime(this?[field], field: field);
  }

  E? getEnum<E>(String field, List<E> values, {E? orElse}) {
    return decodeEnum(this?[field], values, field: field, orElse: orElse);
  }
}

DateTime? decodeDateTime(value, {String? field}) {
  if(value is String) {
    value = DateTime.parse(value);
  }
  if(value is num) {
    value = DateTime.fromMillisecondsSinceEpoch(value.toInt());
  }
  if(value is DateTime) {
    if(field != null) {
      if(field == 'date' || field.endsWith('Date') || field.endsWith('On')) {
        value = DateTime(value.year, value.month, value.day);
      }
      if(field == 'time' || field.endsWith('Time') || field.endsWith('At')) {
        value = DateTime(1, 1, 1, value.hour, value.minute, value.second);
      }
    }
    return value;
  }
  return null;
}

Set<String> decodeSet(data, String field, [bool Function(dynamic v)? filter]) {
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

String? encodeEnum(data) {
  final split = data.toString().split('.');
  return (split.length > 1 && split[0] == data.runtimeType.toString()) ? split[1] : null;
}

E? decodeEnum<E>(data, List<E> values, {E? orElse, String? field}) {
  if(data is Map) {
    data = data[field];
  }
  if(data is String) {
    for(final v in values) {
      if(encodeEnum(v) == data) {
        return v;
      }
    }
  }
  return orElse;
}
