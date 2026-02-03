import 'package:drift/drift.dart';

/// Stores/Branches table - supports multi-location operations
class Stores extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get code => text().withLength(min: 1, max: 10).unique()(); // e.g., "MAIN", "BR01"
  TextColumn get name => text().withLength(min: 1, max: 100)(); // e.g., "Main Store", "Branch 1"
  TextColumn get address => text().nullable()();
  TextColumn get phone => text().nullable()();
  BoolColumn get isMainTerminal => boolean().withDefault(const Constant(false))(); // True for server
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get vpnAddress => text().nullable()(); // VPN IP for sync (e.g., "10.8.0.1")
  IntColumn get syncPort => integer().nullable()(); // Port for sync service
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get lastSyncAt => dateTime().nullable()();
}

/// Sync log - tracks what data has been synced between terminals
class SyncLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get sourceStoreId => integer().references(Stores, #id)();
  IntColumn get targetStoreId => integer().references(Stores, #id)();
  TextColumn get entityType => text()(); // "order", "product", "customer", etc.
  IntColumn get entityId => integer()(); // ID of the synced record
  TextColumn get syncStatus => text()(); // "pending", "success", "failed"
  TextColumn get errorMessage => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get syncedAt => dateTime().nullable()();
}

/// Data change queue - tracks local changes to be pushed to server
class ChangeQueue extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get storeId => integer().references(Stores, #id)();
  TextColumn get entityType => text()(); // "order", "product", "inventory"
  IntColumn get entityId => integer()();
  TextColumn get operation => text()(); // "create", "update", "delete"
  TextColumn get payload => text()(); // JSON data
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get syncedAt => dateTime().nullable()();
}
