import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  final database = ref.watch(databaseProvider);
  return SettingsRepository(database);
});

class SettingsRepository {
  final AppDatabase _database;

  SettingsRepository(this._database);

  Stream<String?> watchSetting(String key) {
    return (_database.select(_database.settings)..where((s) => s.key.equals(key)))
        .watchSingleOrNull()
        .map((row) => row?.value);
  }

  Future<String?> getSetting(String key) async {
    final row = await (_database.select(_database.settings)..where((s) => s.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> setSetting(String key, String? value) async {
    if (value == null || value.isEmpty) {
      await (_database.delete(_database.settings)..where((s) => s.key.equals(key))).go();
      return;
    }

    await _database.into(_database.settings).insert(
          SettingsCompanion.insert(
            key: key,
            value: value,
          ),
          mode: InsertMode.insertOrReplace,
        );
  }
}
