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
}

class OrderItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get orderId => integer().references(Orders, #id)();
  IntColumn get productId => integer().references(Products, #id)(); // Link to product
  TextColumn get productName => text()(); // Store name in case product is deleted/renamed
  RealColumn get quantity => real()();
  RealColumn get unitPrice => real()();
  RealColumn get total => real()(); // quantity * unitPrice
  TextColumn get note => text().nullable()(); // Kitchen notes
}
