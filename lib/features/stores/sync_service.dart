import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/database.dart';
import 'store_repository.dart';
import 'store_providers.dart';

final syncServiceProvider = Provider<SyncService>((ref) {
  final repository = ref.watch(storeRepositoryProvider);
  final currentStore = ref.watch(currentStoreProvider);
  return SyncService(repository, currentStore);
});

class SyncService {
  final StoreRepository _repository;
  final Store? _currentStore;

  SyncService(this._repository, this._currentStore);

  // Queue a change for sync
  Future<void> queueChange({
    required String entityType,
    required String operation,
    required int entityId,
    required Map<String, dynamic> data,
  }) async {
    if (_currentStore == null) return;

    final payload = jsonEncode(data);
    await _repository.addToChangeQueue(
      ChangeQueueCompanion(
        storeId: Value(_currentStore.id),
        entityType: Value(entityType),
        entityId: Value(entityId),
        operation: Value(operation),
        payload: Value(payload),
        synced: const Value(false),
        createdAt: Value(DateTime.now()),
      ),
    );
  }

  // Queue order change
  Future<void> queueOrderChange(int orderId, String operation, Map<String, dynamic> orderData) {
    return queueChange(
      entityType: 'order',
      operation: operation,
      entityId: orderId,
      data: orderData,
    );
  }

  // Queue product change
  Future<void> queueProductChange(int productId, String operation, Map<String, dynamic> productData) {
    return queueChange(
      entityType: 'product',
      operation: operation,
      entityId: productId,
      data: productData,
    );
  }

  // Queue customer change
  Future<void> queueCustomerChange(int customerId, String operation, Map<String, dynamic> customerData) {
    return queueChange(
      entityType: 'customer',
      operation: operation,
      entityId: customerId,
      data: customerData,
    );
  }

  // Log sync operation
  Future<int> logSync({
    required int targetStoreId,
    required String entityType,
    required int entityId,
    String status = 'pending',
  }) async {
    if (_currentStore == null) return -1;

    return _repository.createSyncLog(
      SyncLogsCompanion(
        sourceStoreId: Value(_currentStore.id),
        targetStoreId: Value(targetStoreId),
        entityType: Value(entityType),
        entityId: Value(entityId),
        syncStatus: Value(status),
        syncedAt: Value(DateTime.now()),
      ),
    );
  }

  // Update sync status
  Future<void> updateSyncStatus(int logId, String status, {String? errorMessage}) {
    return _repository.updateSyncStatus(logId, status, errorMessage: errorMessage);
  }

  // Mark change as synced
  Future<void> markChangeSynced(int changeId) {
    return _repository.markChangeSynced(changeId);
  }

  // Clear synced changes
  Future<void> clearSyncedChanges() async {
    if (_currentStore == null) return;
    await _repository.clearSyncedChanges(_currentStore.id);
  }

  // Get pending changes count
  Future<int> getPendingChangesCount() async {
    if (_currentStore == null) return 0;
    
    final changes = await _repository.watchPendingChanges(_currentStore.id).first;
    return changes.length;
  }

  // Update last sync time
  Future<void> updateLastSync() async {
    if (_currentStore == null) return;
    await _repository.updateLastSync(_currentStore.id, DateTime.now());
  }
}
