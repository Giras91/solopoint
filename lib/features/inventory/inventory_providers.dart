import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/database.dart';
import 'inventory_repository.dart';

// Stream of all categories
final categoryListProvider = StreamProvider<List<Category>>((ref) {
  final repository = ref.watch(inventoryRepositoryProvider);
  return repository.watchAllCategories();
});

// Stream of all products
final productListProvider = StreamProvider<List<Product>>((ref) {
  final repository = ref.watch(inventoryRepositoryProvider);
  return repository.watchAllProducts();
});
