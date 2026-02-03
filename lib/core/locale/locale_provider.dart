import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/settings/data/settings_repository.dart';

const _localeSettingKey = 'locale';

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale?>((ref) {
  return LocaleNotifier(ref);
});

class LocaleNotifier extends StateNotifier<Locale?> {
  final Ref _ref;

  LocaleNotifier(this._ref) : super(null) {
    _load();
  }

  Future<void> _load() async {
    final repo = _ref.read(settingsRepositoryProvider);
    final stored = await repo.getSetting(_localeSettingKey);
    if (stored == null || stored.isEmpty) {
      state = null;
      return;
    }
    state = Locale(stored);
  }

  Future<void> setLocale(Locale? locale) async {
    final repo = _ref.read(settingsRepositoryProvider);
    state = locale;
    await repo.setSetting(_localeSettingKey, locale?.languageCode ?? '');
  }
}
