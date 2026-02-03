import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import '../database/database.dart';

/// Initialize default data in the database
Future<void> initializeDatabaseDefaults(AppDatabase database) async {
  // Check if any user exists
  final userCount = await database.select(database.users).get().then((users) => users.length);
  
  if (userCount == 0) {
    // Create default admin user with PIN: 1234
    await database.into(database.users).insert(
      UsersCompanion(
        name: const Value('Admin'),
        pin: const Value('1234'),
        role: const Value('admin'),
        isActive: const Value(true),
      ),
    );

    // Create default staff users
    await database.into(database.users).insert(
      UsersCompanion(
        name: const Value('Staff 1'),
        pin: const Value('5678'),
        role: const Value('staff'),
        isActive: const Value(true),
      ),
    );
    // ignore: avoid_print
    print('✓ Default users initialized');
  }

  // Check if any settings exist
  final settingsCount = await database.select(database.settings).get().then((s) => s.length);
  if (settingsCount == 0) {
    // Initialize default settings
    await database.into(database.settings).insert(
      SettingsCompanion(
        key: const Value('tax_rate'),
        value: const Value('0.10'), // 10% tax
      ),
    );
    
    await database.into(database.settings).insert(
      SettingsCompanion(
        key: const Value('currency_symbol'),
        value: const Value('RM'), // Malaysian Ringgit
      ),
    );

    await database.into(database.settings).insert(
      SettingsCompanion(
        key: const Value('business_name'),
        value: const Value('SoloPoint POS'),
      ),
    );
    // ignore: avoid_print
    print('✓ Default settings initialized');
  }

  // Check if any categories exist
  final categoryCount = await database.select(database.categories).get().then((c) => c.length);
  if (categoryCount == 0) {
    // Create default categories
    final beveragesId = await database.into(database.categories).insert(
      CategoriesCompanion(
        name: const Value('Beverages'),
        color: const Value(0xFF2196F3), // Blue
      ),
    );

    final foodId = await database.into(database.categories).insert(
      CategoriesCompanion(
        name: const Value('Food'),
        color: const Value(0xFFFF9800), // Orange
      ),
    );

    final snacksId = await database.into(database.categories).insert(
      CategoriesCompanion(
        name: const Value('Snacks'),
        color: const Value(0xFF4CAF50), // Green
      ),
    );

    // Create default products
    await database.into(database.products).insert(
      ProductsCompanion(
        categoryId: Value(beveragesId),
        name: const Value('Coffee'),
        sku: const Value('SKU-001'),
        price: const Value(3.50),
        cost: const Value(1.00),
        stockQuantity: const Value(100),
        trackStock: const Value(true),
      ),
    );

    await database.into(database.products).insert(
      ProductsCompanion(
        categoryId: Value(beveragesId),
        name: const Value('Iced Tea'),
        sku: const Value('SKU-002'),
        price: const Value(2.00),
        cost: const Value(0.50),
        stockQuantity: const Value(150),
        trackStock: const Value(true),
      ),
    );

    await database.into(database.products).insert(
      ProductsCompanion(
        categoryId: Value(foodId),
        name: const Value('Sandwich'),
        sku: const Value('SKU-003'),
        price: const Value(5.00),
        cost: const Value(2.00),
        stockQuantity: const Value(50),
        trackStock: const Value(true),
      ),
    );

    await database.into(database.products).insert(
      ProductsCompanion(
        categoryId: Value(snacksId),
        name: const Value('Chips'),
        sku: const Value('SKU-004'),
        price: const Value(1.50),
        cost: const Value(0.50),
        stockQuantity: const Value(200),
        trackStock: const Value(true),
      ),
    );
    // ignore: avoid_print
    print('✓ Default categories and products initialized');
  }
}

/// Provider to ensure database is initialized on app start
final databaseInitializationProvider = FutureProvider<void>((ref) async {
  final database = ref.watch(databaseProvider);
  await initializeDatabaseDefaults(database);
});
