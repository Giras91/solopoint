import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import '../../core/database/database.dart';

final stockAlertRepositoryProvider = Provider<StockAlertRepository>((ref) {
  final database = ref.watch(databaseProvider);
  return StockAlertRepository(database);
});

class StockAlertRepository {
  final AppDatabase _db;

  StockAlertRepository(this._db);

  // Watch all stock alerts
  Stream<List<StockAlert>> watchAllAlerts() {
    return _db.select(_db.stockAlerts).watch();
  }

  // Get alert for product or variant
  Future<StockAlert?> getAlert({int? productId, int? variantId}) {
    final query = _db.select(_db.stockAlerts);
    
    if (variantId != null) {
      query.where((a) => a.variantId.equals(variantId));
    } else if (productId != null) {
      query.where((a) => a.productId.equals(productId) & a.variantId.isNull());
    }
    
    return query.getSingleOrNull();
  }

  // Create or update alert
  Future<void> setAlert({
    required int productId,
    int? variantId,
    required double lowStockThreshold,
    bool isEnabled = true,
  }) async {
    final existing = await getAlert(productId: productId, variantId: variantId);
    
    if (existing != null) {
      // Update existing
      await (_db.update(_db.stockAlerts)
            ..where((a) => a.id.equals(existing.id)))
          .write(StockAlertsCompanion(
        lowStockThreshold: Value(lowStockThreshold),
        isEnabled: Value(isEnabled),
      ));
    } else {
      // Create new
      await _db.into(_db.stockAlerts).insert(StockAlertsCompanion(
        productId: Value(productId),
        variantId: Value(variantId),
        lowStockThreshold: Value(lowStockThreshold),
        isEnabled: Value(isEnabled),
      ));
    }
  }

  // Delete alert
  Future<int> deleteAlert(int id) {
    return (_db.delete(_db.stockAlerts)..where((a) => a.id.equals(id))).go();
  }

  // Get all low stock items (products and variants)
  Future<List<LowStockItem>> getLowStockItems() async {
    // Query for products with low stock
    final productsQuery = '''
      SELECT 
        p.id as productId,
        NULL as variantId,
        p.name as productName,
        NULL as variantName,
        p.stockQuantity as currentStock,
        sa.lowStockThreshold as threshold
      FROM products p
      INNER JOIN stock_alerts sa ON p.id = sa.productId AND sa.variantId IS NULL
      WHERE sa.isEnabled = 1 AND p.trackStock = 1 AND p.stockQuantity <= sa.lowStockThreshold
    ''';

    // Query for variants with low stock
    final variantsQuery = '''
      SELECT 
        pv.productId as productId,
        pv.id as variantId,
        p.name as productName,
        pv.name as variantName,
        pv.stockQuantity as currentStock,
        sa.lowStockThreshold as threshold
      FROM product_variants pv
      INNER JOIN products p ON pv.productId = p.id
      INNER JOIN stock_alerts sa ON pv.id = sa.variantId
      WHERE sa.isEnabled = 1 AND pv.isActive = 1 AND pv.stockQuantity <= sa.lowStockThreshold
    ''';

    final combinedQuery = '''
      $productsQuery
      UNION ALL
      $variantsQuery
      ORDER BY currentStock ASC
    ''';

    final result = await _db.customSelect(combinedQuery).get();
    
    return result.map((row) => LowStockItem(
      productId: row.read<int>('productId'),
      variantId: row.readNullable<int>('variantId'),
      productName: row.read<String>('productName'),
      variantName: row.readNullable<String>('variantName'),
      currentStock: row.read<double>('currentStock'),
      threshold: row.read<double>('threshold'),
    )).toList();
  }

  // Update last alert time
  Future<void> updateLastAlertTime(int alertId) {
    return (_db.update(_db.stockAlerts)..where((a) => a.id.equals(alertId)))
        .write(StockAlertsCompanion(
      lastAlertAt: Value(DateTime.now()),
    ));
  }
}

// Data class for low stock items
class LowStockItem {
  final int productId;
  final int? variantId;
  final String productName;
  final String? variantName;
  final double currentStock;
  final double threshold;

  LowStockItem({
    required this.productId,
    required this.variantId,
    required this.productName,
    required this.variantName,
    required this.currentStock,
    required this.threshold,
  });

  String get displayName {
    if (variantName != null) {
      return '$productName - $variantName';
    }
    return productName;
  }
}
