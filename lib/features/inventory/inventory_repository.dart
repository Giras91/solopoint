import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/database.dart';

// Riverpod Provider
final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return InventoryRepository(db);
});

class InventoryRepository {
  final AppDatabase _db;

  InventoryRepository(this._db);

  // --- Categories ---

  Future<int> addCategory(CategoriesCompanion category) {
    return _db.into(_db.categories).insert(category);
  }

  Future<List<Category>> getAllCategories() {
    return _db.select(_db.categories).get();
  }

  Stream<List<Category>> watchAllCategories() {
    return _db.select(_db.categories).watch();
  }

  Future<bool> updateCategory(Category category) {
    return _db.update(_db.categories).replace(category);
  }

  Future<int> deleteCategory(int id) {
    return (_db.delete(_db.categories)..where((t) => t.id.equals(id))).go();
  }

  // --- Products ---

  Future<int> addProduct(ProductsCompanion product) {
    return _db.into(_db.products).insert(product);
  }

  Future<List<Product>> getAllProducts() {
    return _db.select(_db.products).get();
  }

  Stream<List<Product>> watchAllProducts() {
    return _db.select(_db.products).watch();
  }
  
  Stream<List<Product>> watchProductsByCategory(int categoryId) {
    return (_db.select(_db.products)..where((t) => t.categoryId.equals(categoryId))).watch();
  }

  Future<bool> updateProduct(Product product) {
    return _db.update(_db.products).replace(product);
  }

  Future<int> deleteProduct(int id) {
    return (_db.delete(_db.products)..where((t) => t.id.equals(id))).go();
  }
}
