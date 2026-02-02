import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import '../../core/database/database.dart';

final variantRepositoryProvider = Provider<VariantRepository>((ref) {
  final database = ref.watch(databaseProvider);
  return VariantRepository(database);
});

class VariantRepository {
  final AppDatabase _db;

  VariantRepository(this._db);

  // Watch all variants for a product
  Stream<List<ProductVariant>> watchVariantsByProduct(int productId) {
    return (_db.select(_db.productVariants)
          ..where((v) => v.productId.equals(productId))
          ..orderBy([(v) => OrderingTerm.asc(v.sortOrder)]))
        .watch();
  }

  // Get single variant
  Future<ProductVariant?> getVariant(int id) {
    return (_db.select(_db.productVariants)..where((v) => v.id.equals(id)))
        .getSingleOrNull();
  }

  // Create variant
  Future<int> createVariant(ProductVariantsCompanion variant) {
    return _db.into(_db.productVariants).insert(variant);
  }

  // Update variant
  Future<int> updateVariant(int id, ProductVariantsCompanion variant) {
    return (_db.update(_db.productVariants)..where((v) => v.id.equals(id)))
        .write(variant);
  }

  // Delete variant
  Future<int> deleteVariant(int id) {
    return (_db.delete(_db.productVariants)..where((v) => v.id.equals(id)))
        .go();
  }

  // Update stock quantity
  Future<int> updateStock(int variantId, double quantity) {
    return (_db.update(_db.productVariants)
          ..where((v) => v.id.equals(variantId)))
        .write(ProductVariantsCompanion(
      stockQuantity: Value(quantity),
    ));
  }

  // Adjust stock (add or subtract)
  Future<void> adjustStock(
    int variantId,
    double quantityChange,
    String movementType, {
    String? reference,
    int? userId,
    String? notes,
  }) async {
    await _db.transaction(() async {
      // Get current stock
      final variant = await getVariant(variantId);
      if (variant == null) return;

      // Update stock quantity
      final newQuantity = variant.stockQuantity + quantityChange;
      await updateStock(variantId, newQuantity);

      // Record movement
      await _db.into(_db.stockMovements).insert(StockMovementsCompanion(
        productId: Value(variant.productId),
        variantId: Value(variantId),
        quantityChange: Value(quantityChange),
        movementType: Value(movementType),
        reference: Value(reference),
        userId: Value(userId),
        notes: Value(notes),
      ));
    });
  }

  // Get stock movement history
  Stream<List<StockMovement>> watchStockMovements({
    int? productId,
    int? variantId,
    int limit = 50,
  }) {
    final query = _db.select(_db.stockMovements)
      ..orderBy([(m) => OrderingTerm.desc(m.timestamp)])
      ..limit(limit);

    if (productId != null) {
      query.where((m) => m.productId.equals(productId));
    }
    if (variantId != null) {
      query.where((m) => m.variantId.equals(variantId));
    }

    return query.watch();
  }
}
