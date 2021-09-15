import 'package:oobium_datastore/oobium_datastore.dart';

class ExampleTestData {
  final DataStore _ds;
  ExampleTestData(String path, {DataStoreObserver? observer})
      : _ds = DataStore('$path/example_test',
            adapters: Adapters([
              Adapter<Inventory>(
                  decode: (m) {
                    m['date'] = DateTime.fromMillisecondsSinceEpoch(m['date']);
                    m['sections'] = HasMany<InventorySection>(key: 'inventory');
                    return Inventory._(m);
                  },
                  encode: (k, v) => v,
                  fields: ['id', 'description', 'date', 'sections']),
              Adapter<InventorySection>(
                  decode: (m) {
                    m['inventory'] = DataId(m['inventory']);
                    m['items'] = HasMany<InventoryItem>(key: 'section');
                    return InventorySection._(m);
                  },
                  encode: (k, v) => v,
                  fields: ['id', 'name', 'inventory', 'items']),
              Adapter<InventoryItem>(
                  decode: (m) {
                    m['section'] = DataId(m['section']);
                    return InventoryItem._(m);
                  },
                  encode: (k, v) => v,
                  fields: ['id', 'name', 'section'])
            ]),
            indexes: [
              DataIndex<Inventory>(toKey: (m) => m.id),
              DataIndex<InventorySection>(toKey: (m) => m.id),
              DataIndex<InventoryItem>(toKey: (m) => m.id)
            ],
            observer: observer);
  Future<ExampleTestData> open(
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
  Inventory? getInventory(int? id, {Inventory? Function()? orElse}) =>
      _ds.get<Inventory>(id, orElse: orElse);
  InventorySection? getInventorySection(int? id,
          {InventorySection? Function()? orElse}) =>
      _ds.get<InventorySection>(id, orElse: orElse);
  InventoryItem? getInventoryItem(int? id,
          {InventoryItem? Function()? orElse}) =>
      _ds.get<InventoryItem>(id, orElse: orElse);
  List<Inventory> getInventories({bool Function(Inventory model)? where}) =>
      _ds.getAll<Inventory>(where: where);
  List<InventorySection> getInventorySections(
          {bool Function(InventorySection model)? where}) =>
      _ds.getAll<InventorySection>(where: where);
  List<InventoryItem> getInventoryItems(
          {bool Function(InventoryItem model)? where}) =>
      _ds.getAll<InventoryItem>(where: where);
  List<Inventory> findInventories({String? description, DateTime? date}) =>
      _ds.getAll<Inventory>(
          where: (m) =>
              (description == null || description == m.description) &&
              (date == null || date == m.date));
  List<InventorySection> findInventorySections(
          {String? name, Inventory? inventory}) =>
      _ds.getAll<InventorySection>(
          where: (m) =>
              (name == null || name == m.name) &&
              (inventory == null || inventory == m.inventory));
  List<InventoryItem> findInventoryItems(
          {String? name, InventorySection? section}) =>
      _ds.getAll<InventoryItem>(
          where: (m) =>
              (name == null || name == m.name) &&
              (section == null || section == m.section));
  T put<T extends ExampleTestModel>(T model) => _ds.put<T>(model);
  List<T> putAll<T extends ExampleTestModel>(Iterable<T> models) =>
      _ds.putAll<T>(models);
  Inventory putInventory(
          {required int id,
          required String description,
          required DateTime date}) =>
      _ds.put(Inventory(id: id, description: description, date: date));
  InventorySection putInventorySection(
          {required int id,
          required String name,
          required Inventory inventory}) =>
      _ds.put(InventorySection(id: id, name: name, inventory: inventory));
  InventoryItem putInventoryItem(
          {required int id,
          required String name,
          required InventorySection section}) =>
      _ds.put(InventoryItem(id: id, name: name, section: section));
  T remove<T extends ExampleTestModel>(T model) => _ds.remove<T>(model);
  List<T> removeAll<T extends ExampleTestModel>(Iterable<T> models) =>
      _ds.removeAll<T>(models);
  Stream<Inventory?> streamInventory(int id) => _ds.stream<Inventory>(id);
  Stream<InventorySection?> streamInventorySection(int id) =>
      _ds.stream<InventorySection>(id);
  Stream<InventoryItem?> streamInventoryItem(int id) =>
      _ds.stream<InventoryItem>(id);
  Stream<DataModelEvent<Inventory>> streamInventories(
          {bool Function(Inventory model)? where}) =>
      _ds.streamAll<Inventory>(where: where);
  Stream<DataModelEvent<InventorySection>> streamInventorySections(
          {bool Function(InventorySection model)? where}) =>
      _ds.streamAll<InventorySection>(where: where);
  Stream<DataModelEvent<InventoryItem>> streamInventoryItems(
          {bool Function(InventoryItem model)? where}) =>
      _ds.streamAll<InventoryItem>(where: where);
}

abstract class ExampleTestModel extends DataModel {
  ExampleTestModel([Map<String, dynamic>? fields]) : super(fields);
  ExampleTestModel.copyNew(
      ExampleTestModel original, Map<String, dynamic>? fields)
      : super.copyNew(original, fields);
  ExampleTestModel.copyWith(
      ExampleTestModel original, Map<String, dynamic>? fields)
      : super.copyWith(original, fields);
  ExampleTestModel.deleted(ExampleTestModel original) : super.deleted(original);
}

class Inventory extends ExampleTestModel {
  int get id => this['id'];
  String get description => this['description'];
  DateTime get date => this['date'];
  HasMany<InventorySection> get sections => this['sections'];

  Inventory(
      {required int id, required String description, required DateTime date})
      : super({
          'id': id,
          'description': description,
          'date': date,
          'sections': HasMany<InventorySection>(key: 'inventory')
        });

  Inventory._(map) : super(map);

  Inventory._copyNew(Inventory original,
      {required int id, required String description, required DateTime date})
      : super.copyNew(
            original, {'id': id, 'description': description, 'date': date});

  Inventory._copyWith(Inventory original, {String? description, DateTime? date})
      : super.copyWith(original, {'description': description, 'date': date});

  Inventory._deleted(Inventory original) : super.deleted(original);

  Inventory copyNew(
          {required int id,
          required String description,
          required DateTime date}) =>
      Inventory._copyNew(this, id: id, description: description, date: date);

  Inventory copyWith({String? description, DateTime? date}) =>
      Inventory._copyWith(this, description: description, date: date);

  @override
  Inventory deleted() => Inventory._deleted(this);
}

class InventorySection extends ExampleTestModel {
  int get id => this['id'];
  String get name => this['name'];
  Inventory get inventory => this['inventory'];
  HasMany<InventoryItem> get items => this['items'];

  InventorySection(
      {required int id, required String name, required Inventory inventory})
      : super({
          'id': id,
          'name': name,
          'inventory': inventory,
          'items': HasMany<InventoryItem>(key: 'section')
        });

  InventorySection._(map) : super(map);

  InventorySection._copyNew(InventorySection original,
      {required int id, required String name, required Inventory inventory})
      : super.copyNew(
            original, {'id': id, 'name': name, 'inventory': inventory});

  InventorySection._copyWith(InventorySection original,
      {String? name, Inventory? inventory})
      : super.copyWith(original, {'name': name, 'inventory': inventory});

  InventorySection._deleted(InventorySection original)
      : super.deleted(original);

  InventorySection copyNew(
          {required int id,
          required String name,
          required Inventory inventory}) =>
      InventorySection._copyNew(this, id: id, name: name, inventory: inventory);

  InventorySection copyWith({String? name, Inventory? inventory}) =>
      InventorySection._copyWith(this, name: name, inventory: inventory);

  @override
  InventorySection deleted() => InventorySection._deleted(this);
}

class InventoryItem extends ExampleTestModel {
  int get id => this['id'];
  String get name => this['name'];
  InventorySection get section => this['section'];

  InventoryItem(
      {required int id,
      required String name,
      required InventorySection section})
      : super({'id': id, 'name': name, 'section': section});

  InventoryItem._(map) : super(map);

  InventoryItem._copyNew(InventoryItem original,
      {required int id,
      required String name,
      required InventorySection section})
      : super.copyNew(original, {'id': id, 'name': name, 'section': section});

  InventoryItem._copyWith(InventoryItem original,
      {String? name, InventorySection? section})
      : super.copyWith(original, {'name': name, 'section': section});

  InventoryItem._deleted(InventoryItem original) : super.deleted(original);

  InventoryItem copyNew(
          {required int id,
          required String name,
          required InventorySection section}) =>
      InventoryItem._copyNew(this, id: id, name: name, section: section);

  InventoryItem copyWith({String? name, InventorySection? section}) =>
      InventoryItem._copyWith(this, name: name, section: section);

  @override
  InventoryItem deleted() => InventoryItem._deleted(this);
}
