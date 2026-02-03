import 'package:drift/drift.dart';
import 'tables.dart'; // Import to reference Products

class Orders extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get orderNumber => text()(); // e.g., ORD-20231025-001
  DateTimeColumn get timestamp => dateTime()();
  TextColumn get status => text().withDefault(const Constant('completed'))(); // pending, completed, void
  RealColumn get subtotal => real()();
  RealColumn get tax => real().withDefault(const Constant(0.0))();
  RealColumn get discount => real().withDefault(const Constant(0.0))();
  RealColumn get total => real()();
  TextColumn get paymentMethod => text().withDefault(const Constant('cash'))(); // cash, card, qr
  IntColumn get tableId => integer().nullable()();
  IntColumn get customerId => integer().nullable()();
  IntColumn get userId => integer().nullable()(); // User who created the order
  IntColumn get storeId => integer().nullable()(); // Store/Branch where order was created
  DateTimeColumn get completedAt => dateTime().nullable()(); // When order was completed
}

class OrderItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get orderId => integer().references(Orders, #id)();
  IntColumn get productId => integer().references(Products, #id)(); // Link to product
  IntColumn get variantId => integer().nullable()(); // Link to product variant if applicable
  TextColumn get productName => text()(); // Store name in case product is deleted/renamed
  TextColumn get variantName => text().nullable()(); // Store variant name (e.g., "Large", "Blue")
  RealColumn get quantity => real()();
  RealColumn get unitPrice => real()();
  RealColumn get total => real()(); // quantity * unitPrice
  TextColumn get note => text().nullable()(); // Kitchen notes
}

class OrderItemModifiers extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get orderItemId => integer().references(OrderItems, #id)();
  TextColumn get modifierName => text()(); // Store name (e.g., "Extra Shot")
  TextColumn get modifierItemName => text()(); // Store item name (e.g., "Large")
  RealColumn get price => real()(); // Price delta applied
}
