import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'gen/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/database/database_init.dart';
import 'core/locale/locale_provider.dart';

void main() {
  runApp(
    const ProviderScope(
      child: SoloPointApp(),
    ),
  );
}

class SoloPointApp extends ConsumerWidget {
  const SoloPointApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Initialize database with default data
    ref.watch(databaseInitializationProvider);

    final locale = ref.watch(localeProvider);

    return MaterialApp.router(
      title: 'SoloPoint',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: goRouter,
      locale: locale,
      supportedLocales: const [
        Locale('en'),
        Locale('fil'),
      ],
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        return RouterListener(child: child ?? const SizedBox.shrink());
      },
    );
  }
}
