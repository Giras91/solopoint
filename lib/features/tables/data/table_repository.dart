import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/database.dart';

// part 'table_repository.g.dart';

final tableRepositoryProvider = Provider<TableRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return TableRepository(db);
});

class TableRepository {
  final AppDatabase _db;

  TableRepository(this._db);

  Future<int> addTable(RestaurantTablesCompanion table) {
    return _db.into(_db.restaurantTables).insert(table);
  }

  Future<bool> updateTable(RestaurantTable table) {
    return _db.update(_db.restaurantTables).replace(table);
  }

  Future<int> deleteTable(int id) {
    return (_db.delete(_db.restaurantTables)..where((t) => t.id.equals(id))).go();
  }

  Stream<List<RestaurantTable>> watchAllTables() {
    return (_db.select(_db.restaurantTables)
          ..orderBy([(t) => OrderingTerm(expression: t.name)]))
        .watch();
  }

  // Method to occupy a table with an order
  Future<void> setTableActiveOrder(int tableId, int orderId) {
    return (_db.update(_db.restaurantTables)..where((t) => t.id.equals(tableId)))
        .write(RestaurantTablesCompanion(activeOrderId: Value(orderId)));
  }

  // Method to free a table
  Future<void> clearTable(int tableId) {
    return (_db.update(_db.restaurantTables)..where((t) => t.id.equals(tableId)))
        .write(const RestaurantTablesCompanion(activeOrderId: Value(null)));
  }
}
