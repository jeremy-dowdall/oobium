import 'package:oobium_common/src/data/database.dart';
import 'package:oobium_common/src/json.dart';
import 'package:oobium_common/src/string.extensions.dart';

class ModelContext {
  final Database db;
  ModelContext(this.db);

  String newId() => db.newId();
  List<T> batch<T extends JsonModel>({Iterable<T> put, Iterable<String> remove}) => db.batch(put: put, remove: remove);
  T get<T extends JsonModel>(String id, {T Function() orElse}) => db.get<T>(id, orElse: orElse);
  Iterable<T> getAll<T extends JsonModel>() => db.getAll<T>();
  T put<T extends JsonModel>(T model) => db.put<T>(model);
  List<T> putAll<T extends JsonModel>(Iterable<T> models) => db.putAll<T>(models);
  void remove(String id) => db.remove(id);
  void removeAll(Iterable<String> ids) => db.removeAll(ids);

}

abstract class Model extends JsonModel {

  final ModelContext context;
  Model(this.context, String id) : super(id);
  Model.fromJson(ModelContext context, data) : this.context = context, super.fromJson(data);

  // void delete({Iterable inBatchWith}) => context.delete(this, inBatchWith: inBatchWith);
  // void save({List<Model> inBatchWith, List<Model> andDelete}) => context.save(this, inBatchWith: inBatchWith, andDelete: andDelete);
}
