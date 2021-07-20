import 'dart:convert';

import 'package:objectid/objectid.dart';

import 'datastore.dart';
import 'datastore/models.dart';

class Adapters {

  final _adapters = <String, Adapter>{};
  Adapters(List<Adapter> adapters) {
    for(final adapter in adapters) {
      final type = adapter.type.toString();
      assert(_adapters[type] == null);
      _adapters[type] = adapter;
    }
  }

  Adapter adapterFor(String type) {
    final converter = _adapters[type];
    if(converter != null) {
      return converter;
    }
    throw 'no converter registered for $type';
  }

  DataModel decodeRecord(DataRecord record) {
    if(record.isDelete) {
      return DataModel.deleted(record.modelId, record.updateId);
    } else {
      final value = adapterFor(record.type).decode({
        '_modelId': record.modelId,
        '_updateId': record.updateId,
        ...jsonDecode(record.data!)
      });
      assert(value is DataModel, 'converter did not return a DataModel: $value');
      return (value as DataModel);
    }
  }

  DataRecord encodeRecord(DataModel model) {
    final type = model.runtimeType.toString();
    final modelId = model['_modelId'].toString();
    final updateId = model['_updateId'].toString();
    if(model.isDeleted) {
      return DataRecord(modelId, updateId, type);
    }
    final adapter = adapterFor(type);
    final map = adapter.fields.fold<Map<String, dynamic>>({}, (a,f) {
      final v = encodeValue(adapter.encode(f, model[f]));
      if(v != null) {
        a[f] = v;
      }
      return a;
    });
    return DataRecord(modelId, updateId, type, jsonEncode(map));
  }

  dynamic encodeValue(v) {
    if(v == null)      return null;
    if(v is HasMany)   return null;
    if(v is DataModel) return v['_modelId'].hexString;
    if(v is DataId)    return v.id?.hexString;
    if(v is ObjectId)  return v.hexString;
    if(v is DateTime)  return v.millisecondsSinceEpoch;
    if(v is String)    return v.isNotEmpty ? v : null;
    if(v is Map)       return v.isNotEmpty ? v : null;
    if(v is Iterable)  return v.isNotEmpty ? v : null;
    if(v is num)       return v;
    if(v is bool)      return v;
    try {
      return v.toJson();
    } catch(e) {
      return  v.toString();
    }
  }
}

class Adapter<T> {

  final T Function(Map<String, dynamic> data) decode;
  final dynamic Function(String key, dynamic value) encode;
  final List<String> fields;
  Type get type => T;

  Adapter({
    required this.decode,
    required this.encode,
    required this.fields,
  });

  // T fromJson(Map<String, dynamic> data);
  // Map<String, dynamic> toJson(T object);
}
