import 'package:drift/drift.dart';
import 'tables.dart';

/// Product Variants - Different SKUs/prices for same product (e.g., sizes, colors)
class ProductVariants extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get productId => integer().references(Products, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text().withLength(min: 1, max: 100)(); // e.g., "Small", "Red"
  TextColumn get sku => text().nullable()();
  TextColumn get barcode => text().nullable()();
  RealColumn get price => real()(); // Override base product price
  RealColumn get cost => real().nullable()(); // Override base product cost
  RealColumn get stockQuantity => real().withDefault(const Constant(0.0))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))(); // Display order
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Stock Alerts Configuration
class StockAlerts extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get productId => integer().references(Products, #id, onDelete: KeyAction.cascade)();
  IntColumn get variantId => integer().nullable().references(ProductVariants, #id, onDelete: KeyAction.cascade)();
  RealColumn get lowStockThreshold => real()(); // Alert when stock <= this value
  BoolColumn get isEnabled => boolean().withDefault(const Constant(true))();
  DateTimeColumn get lastAlertAt => dateTime().nullable()(); // Track last alert time
}

/// Stock Movement History (optional for future tracking)
class StockMovements extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get productId => integer().references(Products, #id)();
  IntColumn get variantId => integer().nullable().references(ProductVariants, #id)();
  RealColumn get quantityChange => real()(); // Positive = addition, Negative = sale/loss
  TextColumn get movementType => text()(); // 'sale', 'restock', 'adjustment', 'return'
  TextColumn get reference => text().nullable()(); // Order ID or adjustment note
  IntColumn get userId => integer().nullable()(); // Who made the change
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();
  TextColumn get notes => text().nullable()();
}
