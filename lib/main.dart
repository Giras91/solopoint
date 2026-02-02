import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/database/database_init.dart';

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

    return MaterialApp.router(
      title: 'SoloPoint',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: goRouter,
      builder: (context, child) {
        return RouterListener(child: child ?? const SizedBox.shrink());
      },
    );
  }
}
