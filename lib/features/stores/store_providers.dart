import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/database.dart';
import 'store_repository.dart';

// Store list provider
final storeListProvider = StreamProvider<List<Store>>((ref) {
  final repository = ref.watch(storeRepositoryProvider);
  return repository.watchAllStores();
});

// Active stores provider
final activeStoresProvider = StreamProvider<List<Store>>((ref) {
  final repository = ref.watch(storeRepositoryProvider);
  return repository.watchActiveStores();
});

// Main terminal provider
final mainTerminalProvider = FutureProvider<Store?>((ref) {
  final repository = ref.watch(storeRepositoryProvider);
  return repository.getMainTerminal();
});

// Current store provider (for branch outlets)
final currentStoreProvider = StateProvider<Store?>((ref) => null);

// Sync logs provider
final syncLogsProvider = StreamProvider<List<SyncLog>>((ref) {
  final repository = ref.watch(storeRepositoryProvider);
  return repository.watchSyncLogs();
});

// Pending changes provider
final pendingChangesProvider = StreamProvider.family<List<ChangeQueueData>, int>(
  (ref, storeId) {
    final repository = ref.watch(storeRepositoryProvider);
    return repository.watchPendingChanges(storeId);
  },
);
