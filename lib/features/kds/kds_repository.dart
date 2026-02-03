import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/database.dart';

final kdsRepositoryProvider = Provider<KdsRepository>((ref) {
  final database = ref.watch(databaseProvider);
  return KdsRepository(database);
});

class KdsRepository {
  final AppDatabase _database;

  KdsRepository(this._database);

  Stream<List<KitchenOrder>> watchKitchenOrders() {
    return (_database.select(_database.orders)
          ..where((o) => o.status.isNotIn(['completed', 'void']))
          ..orderBy([(o) => OrderingTerm(expression: o.timestamp, mode: OrderingMode.asc)]))
        .watch()
        .asyncMap((orders) async {
      if (orders.isEmpty) return [];

      final tableIds = orders.where((o) => o.tableId != null).map((o) => o.tableId!).toSet();
      final tables = tableIds.isEmpty
          ? <RestaurantTable>[]
          : await (_database.select(_database.restaurantTables)..where((t) => t.id.isIn(tableIds)))
              .get();
      final tableMap = {for (final t in tables) t.id: t};

      final results = <KitchenOrder>[];
      for (final order in orders) {
        final items = await (_database.select(_database.orderItems)
              ..where((i) => i.orderId.equals(order.id)))
            .get();

        results.add(
          KitchenOrder(
            order: order,
            items: items,
            tableName: order.tableId != null ? tableMap[order.tableId]?.name : null,
          ),
        );
      }

      return results;
    });
  }

  Future<void> updateOrderStatus(int orderId, String status) async {
    final order = await (_database.select(_database.orders)..where((o) => o.id.equals(orderId)))
        .getSingleOrNull();
    if (order == null) return;

    await _database.update(_database.orders).replace(order.copyWith(status: status));
  }
}

class KitchenOrder {
  final Order order;
  final List<OrderItem> items;
  final String? tableName;

  KitchenOrder({
    required this.order,
    required this.items,
    required this.tableName,
  });
}
