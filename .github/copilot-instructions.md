# AI Coding Agent Instructions for SoloPoint

## Project Overview
SoloPoint is a comprehensive Flutter POS (Point of Sale) application targeting multiple platforms (Android, iOS, Windows, etc.).
- **Framework**: Flutter (Environment SDK: ^3.10.7)
- **State Management**: flutter_riverpod
- **Database**: drift (SQLite)
- **Navigation**: go_router

## Architectural Patterns

### 1. Directory Structure
Follow a **Feature-First** architecture.
- `lib/core/`: Shared utilities, database config, theme, routing.
- `lib/features/<feature_name>/`: Self-contained feature modules.
    - `presentation/`: UI screens and widgets.
    - `*_repository.dart`: Data access layer (Drift interfaces).
    - `*_providers.dart`: Riverpod providers for the feature.
    - `*_notifier.dart`: StateNotifiers for complex business logic (e.g., Cart).

### 2. State Management (Riverpod)
- **Data Access**: Use `StreamProvider` for fetching data from the repository to ensure UI updates automatically when the database changes.
- **Business Logic**: Use `StateNotifierProvider` (or `NotifierProvider`) for managing complex local state like the POS Cart or Form entry.
- **Dependency Injection**: Access the database via `ref.watch(databaseProvider)`.

**Example:**
```dart
// Provider definition
final productListProvider = StreamProvider<List<Product>>((ref) {
  final repository = ref.watch(inventoryRepositoryProvider);
  return repository.watchAllProducts();
});

// UI usage
ref.watch(productListProvider).when(...)
```

### 3. Database (Drift)
- **Definition**: Entities/Tables are defined in `lib/core/database/*.dart`.
- **Usage**:
    - Use `...Companion` classes (e.g., `ProductsCompanion`) for Inserts.
    - Use `watch()` on queries to expose Streams for UI.
    - Repositories should encapsulate all Drift queries.
- **Migration**: Always update `schemaVersion` and implementations in `AppDatabase.migration` when modifying tables.

### 4. Navigation (GoRouter)
- Define all routes in `lib/core/router/app_router.dart`.
- Use string-based paths (e.g., `/settings/printer`).

## Development Workflows

### Code Generation
This project uses `build_runner` for Drift (Database) and Riverpod (if specific annotations are used).
- **Run always after DB schema changes**:
  `dart run build_runner build -d`
- **Watch mode during development**:
  `dart run build_runner watch -d`

### Testing
- Place unit/widget tests in `test/`.
- Use `flutter_test` for verifying logic.

## Project Conventions
- **Naming**: Use snake_case for files, camelCase for classes/vars.
- **Imports**: Prefer relative imports within features (`../../core/...`) or package imports? (Codebase uses `../../core` style relative imports).
- **Theme**: Use `AppTheme` in `lib/core/theme/` and access via `Theme.of(context)`.

## Integration Points
- **Printing**: Uses `blue_thermal_printer` and `esc_pos_utils_plus`.
- **Permissions**: Uses `permission_handler` which may require platform-specific config in AndroidManifest.xml or Info.plist.
