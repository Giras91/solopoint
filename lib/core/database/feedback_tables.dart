import 'package:drift/drift.dart';
import 'user_tables.dart';
import 'order_tables.dart';

class CustomerFeedbacks extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get orderId => integer().nullable().references(Orders, #id)();
  IntColumn get customerId => integer().nullable().references(Customers, #id)();
  IntColumn get userId => integer().nullable().references(Users, #id)();
  IntColumn get rating => integer()(); // 1-5 stars
  IntColumn get npsScore => integer().nullable()(); // 0-10
  TextColumn get comment => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}