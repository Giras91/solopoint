# AI Coding Agent Instructions for SoloPoint

## Project snapshot
- Offline Flutter POS targeting Android/iOS/Windows using Flutter, Riverpod, Drift (SQLite), and GoRouter.
- Feature-first layout under lib/features/<feature>/ with layered composition.

## Architecture & data flow
- UI lives in presentation; data access lives in repositories and providers. Example flow: [lib/features/inventory/inventory_repository.dart](lib/features/inventory/inventory_repository.dart) -> [lib/features/inventory/inventory_providers.dart](lib/features/inventory/inventory_providers.dart) -> screens in [lib/features/inventory/presentation](lib/features/inventory/presentation).
- Reactive data uses `StreamProvider` with UI `.when()` handling (see [lib/features/inventory/inventory_providers.dart](lib/features/inventory/inventory_providers.dart)).
- Local state uses `StateNotifierProvider` (cart logic in [lib/features/pos/cart_provider.dart](lib/features/pos/cart_provider.dart)).
- Auth is a `StateNotifier`; role-based routing is handled by `RouterListener` in [lib/core/router/app_router.dart](lib/core/router/app_router.dart) and state in [lib/features/auth/auth_provider.dart](lib/features/auth/auth_provider.dart).

## Database (Drift)
- Tables are split across files under [lib/core/database](lib/core/database); `AppDatabase` and `schemaVersion` live in [lib/core/database/database.dart](lib/core/database/database.dart).
- Schema changes require: update table definitions, bump `schemaVersion`, and add a migration in `AppDatabase.migration`; then run `dart run build_runner build -d` for codegen.
- Inserts/updates use Companion classes (see [lib/core/database/database_init.dart](lib/core/database/database_init.dart)).
- Default data seeding runs via `databaseInitializationProvider` in [lib/core/database/database_init.dart](lib/core/database/database_init.dart) and is triggered in [lib/main.dart](lib/main.dart).

## Navigation
- GoRouter routes are defined in [lib/core/router/app_router.dart](lib/core/router/app_router.dart), with protected routes nested under `/`.
- Role-based landing routes: admin/manager -> /admin, cashier/staff -> /pos.

## Integrations & cross-feature behavior
- POS barcode search + add-to-cart flow lives in [lib/features/pos/presentation/pos_screen.dart](lib/features/pos/presentation/pos_screen.dart).
- Printer integration is encapsulated in `PrinterService` (Bluetooth is currently stubbed) in [lib/features/settings/data/printer_service.dart](lib/features/settings/data/printer_service.dart).
- Restaurant/table flow lives under [lib/features/tables](lib/features/tables); POS accepts optional table context (see [lib/features/pos/presentation/pos_screen.dart](lib/features/pos/presentation/pos_screen.dart)).

## Conventions
- Files: snake_case; classes/methods: camelCase.
- Prefer relative imports within features (see examples in [lib/features/inventory/inventory_repository.dart](lib/features/inventory/inventory_repository.dart)).
