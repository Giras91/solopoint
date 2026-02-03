import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../gen/app_localizations.dart';
import '../../../core/locale/locale_provider.dart';

class LanguageSettingsScreen extends ConsumerWidget {
  const LanguageSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context)!;
    final currentLocale = ref.watch(localeProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.languageSettingsTitle),
      ),
      body: ListView(
        children: [
          ListTile(
            title: Text(localizations.languageSystem),
            trailing: currentLocale == null
                ? const Icon(Icons.check, color: Colors.green)
                : null,
            onTap: () => _setLocale(ref, null, context),
          ),
          ListTile(
            title: Text(localizations.languageEnglish),
            trailing: currentLocale?.languageCode == 'en'
                ? const Icon(Icons.check, color: Colors.green)
                : null,
            onTap: () => _setLocale(ref, const Locale('en'), context),
          ),
          ListTile(
            title: Text(localizations.languageFilipino),
            trailing: currentLocale?.languageCode == 'fil'
                ? const Icon(Icons.check, color: Colors.green)
                : null,
            onTap: () => _setLocale(ref, const Locale('fil'), context),
          ),
        ],
      ),
    );
  }

  void _setLocale(WidgetRef ref, Locale? locale, BuildContext context) {
    ref.read(localeProvider.notifier).setLocale(locale);
    final localizations = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(localizations.languageUpdated)),
    );
  }
}
