import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:oobium/oobium.dart';
import 'package:oobium_client/oobium_client.dart';

class FirePersistor implements Persistor {

  @override
  String newId<T>(ModelContext context) => collection(T).document().documentID;

  @override
  Future<bool> any<T>(ModelContext context, Iterable<Where> conditions, {source = Source.serverAndCache}) async {
    final query = (conditions ?? []).fold<Query>(collection(T), (query, condition) => query.apply(condition));
    return (await query.getDocuments(source: source)).documents.any((document) => document.exists);
  }

  @override
  Future<bool> exists<T>(ModelContext context, String id, {source = Source.serverAndCache}) async {
    final snapshot = await collection(T).document(id).get(source: source);
    return snapshot.exists;
  }

  @override
  Future<T> get<T>(ModelContext context, String id, {T orElse, source = Source.serverAndCache}) async {
    final snapshot = await collection(T).document(id).get(source: source);
    return snapshot.exists ? context.build<T>(snapshot.data) : orElse;
  }

  @override
  Future<List<T>> getAll<T>(ModelContext context, Iterable<Where> conditions, {source = Source.serverAndCache}) async {
    final query = (conditions ?? []).fold<Query>(collection(T), (query, condition) => query.apply(condition));
    return (await query.getDocuments(source: source)).documents.map((e) => context.build<T>(e.data)).toList();
  }

  @override
  Stream<T> stream<T>(ModelContext context, String id, {void onData(T event), Function onError, void onDone(), bool cancelOnError}) {
    return collection(T).document(id).snapshots().map((event) => event.exists ? context.build<T>(event.data) : null);
  }

  @override
  Stream<List<T>> streamAll<T>(ModelContext context, Iterable<Where> conditions, {void onData(T event), Function onError, void onDone(), bool cancelOnError}) {
    final query = (conditions ?? []).fold<Query>(collection(T), (query, condition) => query.apply(condition));
    return query.snapshots().map((event) => event.documents.map((document) => context.build<T>(document.data)).toList());
  }

  @override
  Future<bool> delete(Model model, {Iterable inBatchWith}) async {
    if(inBatchWith == null || inBatchWith.isEmpty) {
      if(model.id != null) await collection(model.runtimeType).document(model.id).delete();
    } else {
      final batch = Firestore.instance.batch();
      Future.forEach([model, ...inBatchWith ], (e) async {
        if(e is JsonModel) {
          if(e.id != null) batch.delete(collection(e.runtimeType).document(e.id));
        }
        else if(e is Link) {
          if(e.id != null) batch.delete(collection(e.type).document(e.id));
        }
        else if(e is HasMany) {
          if(e.isResolved) {
            e.models.forEach((m) {
              if(m.id != null) batch.delete(collection(e.type).document(m.id));
            });
          } else {
            final snapshot = await collection(e.type).where('owner', isEqualTo: e.ownerId).where(e.field, isEqualTo: e.id).getDocuments();
            snapshot.documents.forEach((snap) {
              batch.delete(snap.reference);
            });
          }
        }
      });
      await batch.commit();
    }
    return true;
  }

  @override
  Future<SaveResult> save(Model model, {List<Model> inBatchWith, List<Model> andDelete}) async {
    final validation = model.validate();
    inBatchWith?.forEach((e) => e.validate(validation));
    if(validation.isFailure) {
      return SaveResult.failure(validation);
    }

    try {
      if(((inBatchWith?.length ?? 0) + (andDelete?.length ?? 0)) == 0) {
        final doc = document(model);
        await doc.setData(json(model, doc.documentID));
        return SaveResult.success([model.copyWith(id: doc.documentID)]);
      } else {
        final batch = Firestore.instance.batch();
        final models = <Model>[ model, if(inBatchWith != null) ...inBatchWith ];
        final docs = models.map((e) => document(e)).toList().asMap();
        docs.forEach((i, doc) {
          batch.setData(doc, json(models[i], doc.documentID));
        });
        if(andDelete != null) andDelete.forEach((model) {
          batch.delete(document(model));
        });
        await batch.commit();
        final saves = docs.map<int, Model>((k,v) => MapEntry(k, models[k].copyWith(id: v.documentID))).values.toList();
        return SaveResult.success(saves);
      }
    } catch(e) {
      return SaveResult.failure(Validation('error during save: $e'));
    }
  }

  static String collectionName(Type type) {
    final s = type.toString();
    final i = s.indexOf('<');
    return ((i == -1) ? s : s.substring(0, i)).underscored.plural;
  }

  static CollectionReference collection(Type type) => Firestore.instance.collection(collectionName(type));

  static DocumentReference document(Model model) => collection(model.runtimeType).document(model.id.orElse(null));

  static Map json(Model model, String id) => model.toJson()
    ..['id'] = model.id.orElse(id)
    ..removeWhere((k,v) => k == null || v == null || (v is String && v.isEmpty) || (v is Map && v.isEmpty) || (v is Iterable && v.isEmpty))
  ;
}

extension QueryExt on Query {
  Query apply(Where condition) => this.where(
    condition.field,
    isEqualTo: condition.isEqualTo,
    isLessThan: condition.isLessThan,
    isLessThanOrEqualTo: condition.isLessThanOrEqualTo,
    isGreaterThan: condition.isGreaterThan,
    isGreaterThanOrEqualTo: condition.isGreaterThanOrEqualTo,
    arrayContains: condition.arrayContains,
    arrayContainsAny: condition.arrayContainsAny,
    whereIn: condition.whereIn,
    isNull: condition.isNull,
  );
}
