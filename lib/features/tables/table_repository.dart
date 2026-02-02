import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import '../../core/database/database.dart';

final tableRepositoryProvider = Provider<TableRepository>((ref) {
  final database = ref.watch(databaseProvider);
  return TableRepository(database);
});

class TableRepository {
  final AppDatabase _db;

  TableRepository(this._db);

  // Watch all tables
  Stream<List<RestaurantTable>> watchAllTables() {
    return (_db.select(_db.restaurantTables)
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .watch();
  }

  // Get single table
  Future<RestaurantTable?> getTable(int id) {
    return (_db.select(_db.restaurantTables)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  // Create table
  Future<int> createTable(RestaurantTablesCompanion table) {
    return _db.into(_db.restaurantTables).insert(table);
  }

  // Update table
  Future<int> updateTable(int id, RestaurantTablesCompanion table) {
    return (_db.update(_db.restaurantTables)..where((t) => t.id.equals(id)))
        .write(table);
  }

  // Delete table
  Future<int> deleteTable(int id) {
    return (_db.delete(_db.restaurantTables)..where((t) => t.id.equals(id)))
        .go();
  }

  // Occupy table (assign active order)
  Future<int> occupyTable(int tableId, int orderId) {
    return (_db.update(_db.restaurantTables)
          ..where((t) => t.id.equals(tableId)))
        .write(RestaurantTablesCompanion(
      activeOrderId: Value(orderId),
    ));
  }

  // Clear table (remove active order)
  Future<int> clearTable(int tableId) {
    return (_db.update(_db.restaurantTables)
          ..where((t) => t.id.equals(tableId)))
        .write(const RestaurantTablesCompanion(
      activeOrderId: Value(null),
    ));
  }

  // Get table status (with active order info if any)
  Future<TableStatus> getTableStatus(int tableId) async {
    final table = await getTable(tableId);
    if (table == null) {
      throw Exception('Table not found');
    }

    if (table.activeOrderId == null) {
      return TableStatus(
        table: table,
        isOccupied: false,
        activeOrder: null,
      );
    }

    final order = await (_db.select(_db.orders)
          ..where((o) => o.id.equals(table.activeOrderId!)))
        .getSingleOrNull();

    return TableStatus(
      table: table,
      isOccupied: order != null && order.status != 'completed',
      activeOrder: order,
    );
  }

  // Get all tables with status
  Stream<List<TableStatus>> watchAllTableStatuses() {
    return watchAllTables().asyncMap((tables) async {
      final statuses = <TableStatus>[];
      for (final table in tables) {
        statuses.add(await getTableStatus(table.id));
      }
      return statuses;
    });
  }

  // Create default tables
  Future<void> createDefaultTables() async {
    final existingTables = await (_db.select(_db.restaurantTables)).get();
    if (existingTables.isNotEmpty) return;

    // Create 12 default tables
    for (int i = 1; i <= 12; i++) {
      await createTable(RestaurantTablesCompanion(
        name: Value('Table $i'),
        capacity: Value(4),
      ));
    }
  }
}

// Data class for table status
class TableStatus {
  final RestaurantTable table;
  final bool isOccupied;
  final Order? activeOrder;

  TableStatus({
    required this.table,
    required this.isOccupied,
    required this.activeOrder,
  });

  String get statusText {
    if (!isOccupied) return 'Available';
    if (activeOrder?.status == 'pending') return 'Occupied';
    return 'Available';
  }

  double? get orderTotal => activeOrder?.total;
}
