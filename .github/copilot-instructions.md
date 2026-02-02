# AI Coding Agent Instructions for SoloPoint

## Project Overview
SoloPoint is a 100% offline Flutter POS (Point of Sale) system targeting Android, iOS, and Windows. It combines retail and restaurant modes with barcode scanning, table management, and loyalty programs. Privacy-first with local data ownership.

**Stack**: Flutter 3.10.7+ | Riverpod state management | Drift (SQLite) | GoRouter

---

## Critical Architecture Patterns

### 1. Feature-First Structure with Layered Composition
Each feature in lib/features/<feature>/ follows this pattern:
- **presentation/**: UI screens/dialogs; no business logic
- ***_repository.dart**: Single source of truth for data access; wraps Drift queries
- ***_providers.dart**: Riverpod provider definitions (StreamProvider for data, StateNotifierProvider for cart logic)
- ***_provider.dart** (singular): Optional simpler provider definitions for features with fewer providers

**Real pattern example** (lib/features/inventory/):
- inventory_repository.dart → single InventoryRepository class with methods like watchAllCategories(), watchProductsByCategory(id)
- inventory_providers.dart → categoryListProvider, productListProvider as StreamProviders
- No state notifiers in inventory; cart logic lives in lib/features/pos/cart_provider.dart instead

### 2. Riverpod Pattern for Data & State
- **Data flows**: Repository → StreamProvider → UI watches provider
- **Local state** (Cart, Forms): Use StateNotifierProvider with custom StateNotifier class
- **Dependency injection**: Always access repo via ef.watch(repositoryProvider) inside providers

**Cart example** (lib/features/pos/cart_provider.dart):
``dart
class CartNotifier extends StateNotifier<CartState> { ... }
final cartProvider = StateNotifierProvider<CartNotifier, CartState>(...);
// UI: ref.watch(cartProvider) to get state; ref.read(cartProvider.notifier).addToCart()
``

### 3. Database & Migrations (Drift)
- Tables defined in lib/core/database/tables.dart, order_tables.dart, etc.
- Main class: lib/core/database/database.dart → AppDatabase with @DriftDatabase() annotation
- **On schema change**: Increment schemaVersion, add migration block in onUpgrade()
- Always use ...Companion classes for inserts (e.g., ProductsCompanion)
- Use watch() for reactive streams; get() for one-time fetches

### 4. Authentication & Navigation Flow
- Auth state in lib/features/auth/auth_provider.dart (StateNotifierProvider)
- Routes in lib/core/router/app_router.dart
- RouterListener watches auth state; redirects /login → / and vice versa
- All feature routes nested under / root route

---

## Developer Workflows

### After Database Schema Changes
``bash
dart run build_runner build -d  # One-time rebuild
# OR for iterative dev:
dart run build_runner watch -d  # Watches for changes
``
Then verify migration block in AppDatabase.migration covers the new version.

### Feature Creation Checklist
1. Create lib/features/<name>/ directory
2. Create <name>_repository.dart with Provider and class wrapping Drift calls
3. Create <name>_providers.dart with StreamProviders/StateNotifierProviders
4. Create presentation/<name>_screen.dart that watches providers with `.when()` pattern
5. Add route to lib/core/router/app_router.dart

### Testing
- Unit tests in 	est/ directory
- Use lutter_test for widget tests
- No special mocking setup discovered; use Drift test utilities if testing DB logic

---

## Codebase Patterns

### Real Examples to Follow

**StreamProvider for reactive data** (e.g., inventory products):
``dart
final productListProvider = StreamProvider<List<Product>>((ref) {
  final repository = ref.watch(inventoryRepositoryProvider);
  return repository.watchAllProducts(); // Stream from DB
});
``

**UI consuming with async handling**:
``dart
ref.watch(productListProvider).when(
  data: (products) => ListView(...),
  loading: () => CircularProgressIndicator(),
  error: (err, st) => Text('Error'),
)
``

**Checkout with customer loyalty** (recent feature):
- Customer selection in checkout dialog uses local StateProvider
- saveOrder() in order repository accepts optional customerId
- Loyalty points calculated as: mount / 10 (1 point per ₱10)
- After order completion, customer record updated with new points/spending

### Conventions
- **Files**: snake_case (e.g., cart_provider.dart)
- **Classes/Methods**: camelCase (e.g., CartNotifier, ddToCart())
- **Imports**: Relative paths preferred within features (e.g., ../../core/database/database.dart)
- **Theme**: Access via Theme.of(context) (defined in lib/core/theme/app_theme.dart)

---

## Integration Points & Special Considerations

### Printing (Bluetooth Thermal)
- Service: lib/features/settings/data/printer_service.dart
- Uses lue_thermal_printer + sc_pos_utils_plus
- Settings stored in database (Settings table, key-value pairs)
- Permission handler required for Android/iOS Bluetooth access

### Barcode Scanning
- Implemented in lib/features/pos/presentation/pos_screen.dart (text input + manual/scanner)
- Barcode field exists on Products table
- Quick search pattern: input → filter products → auto-add to cart

### Multi-Mode Support (Retail vs Restaurant)
- Restaurant mode: Table management (lib/features/tables/)
- Retail mode: Standard POS
- Same order/transaction system; tables optional (nullable on Order)

### Database Initialization
- lib/core/database/database_init.dart creates default data on first run (Admin PIN: 1234, settings)
- Triggered in main.dart via databaseInitializationProvider

---

## Common Pitfalls to Avoid
- Don't bypass repositories; Drift queries belong only in *_repository.dart
- Don't forget ef.watch() vs ef.read() distinction (watch = reactive, read = one-time)
- Schema changes without migration update = runtime errors; always bump schemaVersion
- Relative imports in dart files should use ../../ not ../; prefer consistent depth from lib/
