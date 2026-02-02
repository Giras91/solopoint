import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import '../../core/database/database.dart';

final inventoryLogsRepositoryProvider =
    Provider<InventoryLogsRepository>((ref) {
  final database = ref.watch(databaseProvider);
  return InventoryLogsRepository(database);
});

class InventoryLogsRepository {
  final AppDatabase _db;

  InventoryLogsRepository(this._db);

  /// Watch all inventory logs
  Stream<List<InventoryLog>> watchAllInventoryLogs() {
    return (_db.select(_db.inventoryLogs)
          ..orderBy([(l) => OrderingTerm.desc(l.timestamp)]))
        .watch();
  }

  /// Watch inventory logs for a specific product
  Stream<List<InventoryLog>> watchProductInventoryLogs(int productId) {
    return (_db.select(_db.inventoryLogs)
          ..where((l) => l.productId.equals(productId))
          ..orderBy([(l) => OrderingTerm.desc(l.timestamp)]))
        .watch();
  }

  /// Watch inventory logs for a specific reason
  Stream<List<InventoryLog>> watchInventoryLogsByReason(String reason) {
    return (_db.select(_db.inventoryLogs)
          ..where((l) => l.reason.equals(reason))
          ..orderBy([(l) => OrderingTerm.desc(l.timestamp)]))
        .watch();
  }

  /// Watch today's inventory logs
  Stream<List<InventoryLog>> watchTodayInventoryLogs() {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

    return (_db.select(_db.inventoryLogs)
          ..where((l) => l.timestamp.isBetweenValues(startOfDay, endOfDay))
          ..orderBy([(l) => OrderingTerm.desc(l.timestamp)]))
        .watch();
  }

  /// Get single inventory log
  Future<InventoryLog?> getInventoryLog(int id) {
    return (_db.select(_db.inventoryLogs)..where((l) => l.id.equals(id)))
        .getSingleOrNull();
  }

  /// Log a sale (negative quantity)
  Future<int> logSale(
    int productId,
    double quantity, {
    int? userId,
    String? notes,
  }) {
    return _db.into(_db.inventoryLogs).insert(
      InventoryLogsCompanion(
        productId: Value(productId),
        changeAmount: Value(-quantity),
        reason: const Value('Sale'),
        userId: Value(userId),
        timestamp: Value(DateTime.now()),
        notes: Value(notes),
      ),
    );
  }

  /// Log stock audit adjustment
  Future<int> logAudit(
    int productId,
    double adjustmentAmount, {
    int? userId,
    String? notes,
  }) {
    return _db.into(_db.inventoryLogs).insert(
      InventoryLogsCompanion(
        productId: Value(productId),
        changeAmount: Value(adjustmentAmount),
        reason: const Value('Audit'),
        userId: Value(userId),
        timestamp: Value(DateTime.now()),
        notes: Value(notes ?? 'Manual stock adjustment'),
      ),
    );
  }

  /// Log waste/damaged product
  Future<int> logWaste(
    int productId,
    double quantity, {
    int? userId,
    String? notes,
  }) {
    return _db.into(_db.inventoryLogs).insert(
      InventoryLogsCompanion(
        productId: Value(productId),
        changeAmount: Value(-quantity),
        reason: const Value('Waste'),
        userId: Value(userId),
        timestamp: Value(DateTime.now()),
        notes: Value(notes ?? 'Waste/damaged product'),
      ),
    );
  }

  /// Log adjustment (restock, manual correction, etc.)
  Future<int> logAdjustment(
    int productId,
    double changeAmount, {
    String reason = 'Adjustment',
    int? userId,
    String? notes,
  }) {
    return _db.into(_db.inventoryLogs).insert(
      InventoryLogsCompanion(
        productId: Value(productId),
        changeAmount: Value(changeAmount),
        reason: Value(reason),
        userId: Value(userId),
        timestamp: Value(DateTime.now()),
        notes: Value(notes),
      ),
    );
  }

  /// Generic log inventory change
  Future<int> logInventoryChange(
    int productId,
    double changeAmount,
    String reason, {
    int? userId,
    String? notes,
  }) {
    return _db.into(_db.inventoryLogs).insert(
      InventoryLogsCompanion(
        productId: Value(productId),
        changeAmount: Value(changeAmount),
        reason: Value(reason),
        userId: Value(userId),
        timestamp: Value(DateTime.now()),
        notes: Value(notes),
      ),
    );
  }

  /// Get inventory logs for a date range
  Future<List<InventoryLog>> getInventoryLogsInRange(
    DateTime startDate,
    DateTime endDate, {
    int? productId,
    String? reason,
  }) async {
    var query = _db.select(_db.inventoryLogs)
      ..where((l) => l.timestamp.isBetweenValues(startDate, endDate));

    if (productId != null) {
      query.where((l) => l.productId.equals(productId));
    }

    if (reason != null) {
      query.where((l) => l.reason.equals(reason));
    }

    query.orderBy([(l) => OrderingTerm.desc(l.timestamp)]);

    return query.get();
  }

  /// Get total quantity change for a product in a date range
  Future<double> getTotalQuantityChangeInRange(
    int productId,
    DateTime startDate,
    DateTime endDate, {
    String? reason,
  }) async {
    final logs = await getInventoryLogsInRange(
      startDate,
      endDate,
      productId: productId,
      reason: reason,
    );

    double total = 0;
    for (final log in logs) {
      total += log.changeAmount;
    }

    return total;
  }

  /// Get waste summary for a date range
  Future<double> getWasteQuantityInRange(
    DateTime startDate,
    DateTime endDate, {
    int? productId,
  }) async {
    var query = _db.select(_db.inventoryLogs)
      ..where((l) =>
          l.reason.equals('Waste') &
          l.timestamp.isBetweenValues(startDate, endDate));

    if (productId != null) {
      query.where((l) => l.productId.equals(productId));
    }

    final logs = await query.get();

    double totalWaste = 0;
    for (final log in logs) {
      // Waste is logged as negative, so sum absolute values
      totalWaste += log.changeAmount.abs();
    }

    return totalWaste;
  }

  /// Get sales summary for a date range
  Future<double> getSalesQuantityInRange(
    DateTime startDate,
    DateTime endDate, {
    int? productId,
  }) async {
    var query = _db.select(_db.inventoryLogs)
      ..where((l) =>
          l.reason.equals('Sale') &
          l.timestamp.isBetweenValues(startDate, endDate));

    if (productId != null) {
      query.where((l) => l.productId.equals(productId));
    }

    final logs = await query.get();

    double totalSales = 0;
    for (final log in logs) {
      // Sales are logged as negative, so sum absolute values
      totalSales += log.changeAmount.abs();
    }

    return totalSales;
  }

  /// Delete inventory log
  Future<int> deleteInventoryLog(int id) {
    return (_db.delete(_db.inventoryLogs)..where((l) => l.id.equals(id)))
        .go();
  }

  /// Update inventory log notes
  Future<int> updateInventoryLogNotes(int id, String notes) {
    return (_db.update(_db.inventoryLogs)..where((l) => l.id.equals(id)))
        .write(InventoryLogsCompanion(notes: Value(notes)));
  }
}
