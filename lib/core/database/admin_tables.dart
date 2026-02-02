import 'package:drift/drift.dart';
import 'user_tables.dart';

/// Role-based access control table
/// Stores role definitions and their permissions as a JSON string (or bitmask)
class Roles extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 50)(); // admin, manager, cashier, staff
  TextColumn get description => text().nullable()();
  /// Permissions stored as JSON string: {"view_reports": true, "manage_inventory": true, ...}
  /// OR as bitmask: 0x0001 = view_reports, 0x0002 = manage_inventory, etc.
  TextColumn get permissions => text().withDefault(const Constant('{}'))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// Attendance & Clock tracking
/// Tracks employee clock in/out and break times
class AttendanceLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get userId => integer().references(Users, #id)();
  TextColumn get action => text()(); // clock_in, clock_out, break_start, break_end
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();
  TextColumn get notes => text().nullable()();
}

/// Inventory stock movement/change logs
/// Tracks all stock changes: Sales, Audits, Waste, Adjustments
class InventoryLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get productId => integer()(); // Reference to Products table
  RealColumn get changeAmount => real()(); // Positive (in) or negative (out)
  TextColumn get reason => text()(); // Sale, Audit, Waste, Adjustment, Restock, Damage
  IntColumn get userId => integer().nullable()(); // Who made the change
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();
  TextColumn get notes => text().nullable()();
}

/// Audit trail/Journal for sensitive actions
/// Non-deletable log of voids, drawer opens, system changes, etc.
/// This is the compliance/audit journal
class AuditJournal extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get userId => integer().nullable()(); // Who performed the action
  TextColumn get action => text()(); // void_order, open_drawer, edit_price, create_user, etc.
  TextColumn get entityType => text().nullable()(); // Order, Drawer, User, Product, etc.
  IntColumn get entityId => integer().nullable()(); // ID of the affected entity
  TextColumn get details => text().nullable()(); // JSON details: {"orderId": 123, "reason": "customer returned"}
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();
  
  /// Mark as immutable - this table should never allow updates or deletes
  /// in normal app flow (only inserts are allowed)
}
