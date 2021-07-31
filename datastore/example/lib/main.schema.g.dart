import 'package:oobium_datastore/oobium_datastore.dart';

class MainData {
  final DataStore _ds;
  MainData(String path, {DataStoreObserver? observer})
      : _ds = DataStore('$path/main',
            adapters: Adapters([
              Adapter<Item>(
                  decode: (m) => Item._(m),
                  encode: (k, v) => v,
                  fields: ['id', 'name'])
            ]),
            indexes: [DataIndex<Item>(toKey: (m) => m.id)],
            observer: observer);
  Future<MainData> open(
          {int version = 1,
          Stream<DataRecord> Function(UpgradeEvent event)? onUpgrade}) =>
      _ds.open(version: version, onUpgrade: onUpgrade).then((_) => this);
  Future<void> flush() => _ds.flush();
  Future<void> close() => _ds.close();
  Future<void> destroy() => _ds.destroy();
  Future<void> reset() => _ds.reset();
  bool get isEmpty => _ds.isEmpty;
  bool get isNotEmpty => _ds.isNotEmpty;
  bool get isOpen => _ds.isOpen;
  bool get isNotOpen => _ds.isNotOpen;
  Item? getItem(int? id, {Item? Function()? orElse}) =>
      _ds.get<Item>(id, orElse: orElse);
  List<Item> getItems({bool Function(Item model)? where}) =>
      _ds.getAll<Item>(where: where);
  List<Item> findItems({String? name}) =>
      _ds.getAll<Item>(where: (m) => (name == null || name == m.name));
  T put<T extends MainModel>(T model) => _ds.put<T>(model);
  List<T> putAll<T extends MainModel>(Iterable<T> models) =>
      _ds.putAll<T>(models);
  Item putItem({required int id, required String name}) =>
      _ds.put(Item(id: id, name: name));
  T remove<T extends MainModel>(T model) => _ds.remove<T>(model);
  List<T> removeAll<T extends MainModel>(Iterable<T> models) =>
      _ds.removeAll<T>(models);
  Stream<Item?> streamItem(int id) => _ds.stream<Item>(id);
  Stream<DataModelEvent<Item>> streamItems(
          {bool Function(Item model)? where}) =>
      _ds.streamAll<Item>(where: where);
}

abstract class MainModel extends DataModel {
  MainModel([Map<String, dynamic>? fields]) : super(fields);
  MainModel.copyNew(MainModel original, Map<String, dynamic>? fields)
      : super.copyNew(original, fields);
  MainModel.copyWith(MainModel original, Map<String, dynamic>? fields)
      : super.copyWith(original, fields);
  MainModel.deleted(MainModel original) : super.deleted(original);
}

class Item extends MainModel {
  int get id => this['id'];
  String get name => this['name'];

  Item({required int id, required String name})
      : super({'id': id, 'name': name});

  Item._(map) : super(map);

  Item._copyNew(Item original, {required int id, required String name})
      : super.copyNew(original, {'id': id, 'name': name});

  Item._copyWith(Item original, {String? name})
      : super.copyWith(original, {'name': name});

  Item._deleted(Item original) : super.deleted(original);

  Item copyNew({required int id, required String name}) =>
      Item._copyNew(this, id: id, name: name);

  Item copyWith({String? name}) => Item._copyWith(this, name: name);

  Item deleted() => Item._deleted(this);
}
