import 'package:test/test.dart';

import 'example_test.schema.g.dart';

void main() async {
  test('???', () async {
    final ds = await ExampleTestData('test-data').open();
    final inventory = ds.putInventory(
      id: 1,
      description: 'inventory 1',
      date: DateTime.now()
    );
    for(var i = 0; i < 100; i++) {
      final section = ds.putInventorySection(
        id: i,
        name: 'section $i',
        inventory: inventory
      );
      for(var j = 0; j < 100; j++) {
        ds.putInventoryItem(
          id: j,
          name: 'item $i-$j',
          section: section
        );
      }
    }
    await ds.close();
    await ds.open();
    expect(ds.getInventories().length, 1);
    expect(ds.getInventory(1)?.sections.toList().length, 100);
    expect(ds.getInventorySections().length, 100);
    expect(ds.getInventoryItems().length, 100);
    for(var i = 0; i < 100; i++) {
      if(i < 99) {
        expect(ds.getInventorySection(i)?.items.toList().length, 0);
      } else {
        expect(ds.getInventorySection(i)?.items.toList().length, 100);
      }
    }
  });
}