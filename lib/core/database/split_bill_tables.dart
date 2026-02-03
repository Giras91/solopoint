import 'package:drift/drift.dart';
import 'order_tables.dart'; // Import Orders and OrderItems tables

/// Split bills - manages bill splitting for restaurant orders
class SplitBills extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get orderId => integer().references(Orders, #id)();
  TextColumn get splitType => text()(); // "by_people", "by_items", "by_amount"
  IntColumn get splitCount => integer()(); // Number of splits
  RealColumn get originalTotal => real()();
  TextColumn get status => text()(); // "pending", "partially_paid", "completed"
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get completedAt => dateTime().nullable()();
}

/// Split bill items - tracks which items belong to which split
class SplitBillItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get splitBillId => integer().references(SplitBills, #id)();
  IntColumn get splitNumber => integer()(); // Which split (1, 2, 3, etc.)
  IntColumn get orderItemId => integer().references(OrderItems, #id).nullable()();
  RealColumn get amount => real()(); // Amount allocated to this split
  RealColumn get paidAmount => real().withDefault(const Constant(0.0))();
  TextColumn get paymentMethod => text().nullable()(); // "cash", "card", "qr"
  BoolColumn get isPaid => boolean().withDefault(const Constant(false))();
  DateTimeColumn get paidAt => dateTime().nullable()();
}

/// Split bill payments - tracks individual payments for each split
class SplitBillPayments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get splitBillId => integer().references(SplitBills, #id)();
  IntColumn get splitNumber => integer()();
  RealColumn get amount => real()();
  RealColumn get cashReceived => real().nullable()();
  RealColumn get change => real().nullable()();
  TextColumn get paymentMethod => text()(); // "cash", "card", "qr"
  TextColumn get transactionReference => text().nullable()(); // For card/QR payments
  DateTimeColumn get paidAt => dateTime().withDefault(currentDateAndTime)();
}
