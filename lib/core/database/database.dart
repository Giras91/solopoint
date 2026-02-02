import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

import 'tables.dart';
import 'order_tables.dart';
import 'restaurant_tables.dart';
import 'user_tables.dart';
import 'modifier_tables.dart';
import 'variant_tables.dart';
import 'admin_tables.dart';

part 'database.g.dart';

@DriftDatabase(tables: [
  Categories,
  Products,
  ProductVariants,
  StockAlerts,
  StockMovements,
  Orders,
  OrderItems,
  OrderItemModifiers,
  RestaurantTables,
  Users,
  Customers,
  Transactions,
  Modifiers,
  ModifierItems,
  Settings,
  Roles,
  AttendanceLogs,
  InventoryLogs,
  AuditJournal,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 7; // Phase 7: Admin tables (Roles, AttendanceLogs, InventoryLogs, AuditJournal)
  
  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          await m.createTable(orders);
          await m.createTable(orderItems);
        }
        if (from < 3) {
          await m.createTable(restaurantTables);
        }
        if (from < 4) {
          await m.createTable(users);
          await m.createTable(customers);
          await m.createTable(transactions);
          await m.createTable(modifiers);
          await m.createTable(modifierItems);
          await m.createTable(settings);
        }
        if (from < 5) {
          // Add new tables for variants and stock management
          await m.createTable(productVariants);
          await m.createTable(stockAlerts);
          await m.createTable(stockMovements);
          
          // Add new columns to Orders table
          await m.addColumn(orders, orders.userId);
          await m.addColumn(orders, orders.completedAt);
          
          // Add new columns to OrderItems table
          await m.addColumn(orderItems, orderItems.variantId);
          await m.addColumn(orderItems, orderItems.variantName);
        }
        if (from < 6) {
          // Phase 6: Add order item modifiers table
          await m.createTable(orderItemModifiers);
        }
        if (from < 7) {
          // Phase 7: Add admin tables for roles, attendance, inventory logs, and audit journal
          await m.createTable(roles);
          await m.createTable(attendanceLogs);
          await m.createTable(inventoryLogs);
          await m.createTable(auditJournal);
        }
      },
    );
  }
}

LazyDatabase _openConnection() {
  // the LazyDatabase util lets us find the right location for the file async.
  return LazyDatabase(() async {
    // put the database file, called db.sqlite here, into the documents folder
    // for your app.
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'solopoint.sqlite'));

    // Also work around limitations on old Android versions
    if (Platform.isAndroid) {
      await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
    }

    // Make sqlite3 pick a more suitable location for temporary files - the
    // one from the system may be inaccessible due to sandboxing.
    final cachebase = (await getTemporaryDirectory()).path;
    // We can't access /tmp on Android, which sqlite3 would try by default.
    // Explicitly tell it about the correct temporary directory.
    sqlite3.tempDirectory = cachebase;

    return NativeDatabase.createInBackground(file);
  });
}

// Global provider for the database
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  // Close the database when the provider is disposed
  ref.onDispose(db.close);
  return db;
});
