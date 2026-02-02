import 'package:drift/drift.dart';
import 'tables.dart';

class Modifiers extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get productId => integer().references(Products, #id)();
  TextColumn get name => text().withLength(min: 1, max: 100)(); // e.g., "Size", "Toppings"
  BoolColumn get isMultipleChoice => boolean().withDefault(const Constant(false))();
}

class ModifierItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get modifierId => integer().references(Modifiers, #id)();
  TextColumn get name => text().withLength(min: 1, max: 100)(); // e.g., "Small", "Large", "Cheese"
  RealColumn get priceDelta => real().withDefault(const Constant(0.0))(); // Additional price (can be negative)
}

class Settings extends Table {
  TextColumn get key => text()(); // e.g., "tax_rate", "currency_symbol", "business_name"
  TextColumn get value => text()(); // The setting value as JSON or string
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {key};
}
