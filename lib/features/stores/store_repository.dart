import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/database.dart';

final storeRepositoryProvider = Provider<StoreRepository>((ref) {
  final database = ref.watch(databaseProvider);
  return StoreRepository(database);
});

class StoreRepository {
  final AppDatabase _database;

  StoreRepository(this._database);

  // Get all stores
  Stream<List<Store>> watchAllStores() {
    return _database.select(_database.stores).watch();
  }

  // Get active stores only
  Stream<List<Store>> watchActiveStores() {
    return (_database.select(_database.stores)
          ..where((tbl) => tbl.isActive.equals(true)))
        .watch();
  }

  // Get main terminal store
  Future<Store?> getMainTerminal() {
    return (_database.select(_database.stores)
          ..where((tbl) => tbl.isMainTerminal.equals(true)))
        .getSingleOrNull();
  }

  // Get store by ID
  Future<Store?> getStoreById(int id) {
    return (_database.select(_database.stores)
          ..where((tbl) => tbl.id.equals(id)))
        .getSingleOrNull();
  }

  // Get store by code
  Future<Store?> getStoreByCode(String code) {
    return (_database.select(_database.stores)
          ..where((tbl) => tbl.code.equals(code)))
        .getSingleOrNull();
  }

  // Create new store
  Future<int> createStore(StoresCompanion store) {
    return _database.into(_database.stores).insert(store);
  }

  // Update store
  Future<bool> updateStore(StoresCompanion store) {
    return _database.update(_database.stores).replace(store);
  }

  // Update last sync time
  Future<void> updateLastSync(int storeId, DateTime syncTime) {
    return (_database.update(_database.stores)
          ..where((tbl) => tbl.id.equals(storeId)))
        .write(StoresCompanion(lastSyncAt: Value(syncTime)));
  }

  // Deactivate store
  Future<void> deactivateStore(int storeId) {
    return (_database.update(_database.stores)
          ..where((tbl) => tbl.id.equals(storeId)))
        .write(const StoresCompanion(isActive: Value(false)));
  }

  // Sync logs
  Stream<List<SyncLog>> watchSyncLogs() {
    return _database.select(_database.syncLogs).watch();
  }

  Future<int> createSyncLog(SyncLogsCompanion log) {
    return _database.into(_database.syncLogs).insert(log);
  }

  Future<void> updateSyncStatus(int logId, String status, {String? errorMessage}) {
    return (_database.update(_database.syncLogs)
          ..where((tbl) => tbl.id.equals(logId)))
        .write(SyncLogsCompanion(
      syncStatus: Value(status),
      errorMessage: Value(errorMessage),
      syncedAt: Value(DateTime.now()),
    ));
  }

  // Change queue management
  Stream<List<ChangeQueueData>> watchChangeQueue() {
    return _database.select(_database.changeQueue).watch();
  }

  Stream<List<ChangeQueueData>> watchPendingChanges(int storeId) {
    return (_database.select(_database.changeQueue)
          ..where((tbl) => tbl.storeId.equals(storeId) & tbl.synced.equals(false)))
        .watch();
  }

  Future<int> addToChangeQueue(ChangeQueueCompanion change) {
    return _database.into(_database.changeQueue).insert(change);
  }

  Future<void> markChangeSynced(int changeId) {
    return (_database.update(_database.changeQueue)
          ..where((tbl) => tbl.id.equals(changeId)))
        .write(ChangeQueueCompanion(
      synced: const Value(true),
      syncedAt: Value(DateTime.now()),
    ));
  }

  Future<void> clearSyncedChanges(int storeId) {
    return (_database.delete(_database.changeQueue)
          ..where((tbl) => tbl.storeId.equals(storeId) & tbl.synced.equals(true)))
        .go();
  }
}
