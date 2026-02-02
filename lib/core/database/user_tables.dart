import 'package:drift/drift.dart';

class Users extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get pin => text().withLength(min: 4, max: 6)(); // 4-6 digit PIN
  TextColumn get role => text().withDefault(const Constant('staff'))(); // admin, staff
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

class Customers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get phone => text().nullable()();
  TextColumn get email => text().nullable()();
  RealColumn get totalSpent => real().withDefault(const Constant(0.0))();
  IntColumn get loyaltyPoints => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get orderId => integer().nullable()(); // Link to order (can be null for manual transactions)
  RealColumn get amount => real()();
  TextColumn get method => text().withDefault(const Constant('cash'))(); // cash, card, qr, etc.
  TextColumn get status => text().withDefault(const Constant('completed'))(); // completed, pending, cancelled
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();
  TextColumn get notes => text().nullable()();
}
