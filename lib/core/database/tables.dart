import 'package:drift/drift.dart';

class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 50)();
  IntColumn get color => integer().nullable()(); // Store 0xFF... color value
  IntColumn get icon => integer().nullable()(); // Store IconData codePoint
}

class Products extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get categoryId => integer().nullable().references(Categories, #id)();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get sku => text().nullable()();
  TextColumn get barcode => text().nullable()();
  RealColumn get price => real().withDefault(const Constant(0.0))();
  RealColumn get cost => real().withDefault(const Constant(0.0))();
  RealColumn get stockQuantity => real().withDefault(const Constant(0.0))();
  BoolColumn get trackStock => boolean().withDefault(const Constant(false))();
  BoolColumn get isVariable => boolean().withDefault(const Constant(false))();
}
