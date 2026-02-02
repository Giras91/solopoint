import 'package:drift/drift.dart';

class RestaurantTables extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 50)();
  IntColumn get capacity => integer().withDefault(const Constant(4))();
  // We can track the current active order ID here to easily check if occupied
  IntColumn get activeOrderId => integer().nullable()();
}
