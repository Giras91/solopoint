import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/database.dart';
import 'inventory_repository.dart';
import 'inventory_logs_repository.dart';

final inventoryLogsProvider = StreamProvider<List<InventoryLog>>((ref) {
  return ref.watch(inventoryLogsRepositoryProvider).watchAllInventoryLogs();
});

final productListStreamProvider = StreamProvider<List<Product>>((ref) {
  return ref.watch(inventoryRepositoryProvider).watchAllProducts();
});
