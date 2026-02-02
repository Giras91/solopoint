import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/auth_provider.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/inventory/presentation/inventory_screen.dart';
import '../../features/pos/presentation/pos_screen.dart';
import '../../features/reports/presentation/reports_screen.dart';
import '../../features/tables/presentation/table_screen.dart';
import '../../features/settings/presentation/printer_settings_screen.dart';
import '../../features/customers/presentation/customer_screen.dart';

// Create a key to maintain navigation state
final rootNavigatorKey = GlobalKey<NavigatorState>();

final goRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/login',
  redirect: (context, state) {
    // This will be handled by the GoRouter redirect logic
    // We'll implement it with a listener approach instead
    return null;
  },
  routes: [
    // Login Route (public)
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    
    // Protected Routes (Dashboard and children)
    GoRoute(
      path: '/',
      builder: (context, state) => const DashboardScreen(),
      routes: [
        GoRoute(
          path: 'tables',
          builder: (context, state) => const TableScreen(),
        ),
        GoRoute(
          path: 'inventory',
          builder: (context, state) => const InventoryScreen(),
        ),
        GoRoute(
          path: 'pos',
          builder: (context, state) => const PosScreen(),
        ),
        GoRoute(
          path: 'reports',
          builder: (context, state) => const ReportsScreen(),
        ),
        GoRoute(
          path: 'customers',
          builder: (context, state) => const CustomerScreen(),
        ),
        GoRoute(
          path: 'settings/printer',
          builder: (context, state) => const PrinterSettingsScreen(),
        ),
      ],
    ),
  ],
);

/// Router Listener for handling auth state changes
class RouterListener extends ConsumerWidget {
  final Widget child;

  const RouterListener({
    required this.child,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch auth state and update route accordingly
    ref.listen(authProvider, (previous, next) {
      if (next == null && previous != null) {
        // User logged out, go to login
        context.go('/login');
      } else if (next != null && previous == null) {
        // User logged in, go to dashboard
        final currentLocation = GoRouterState.of(context).uri.toString();
        if (currentLocation == '/login') {
          context.go('/');
        }
      }
    });

    return child;
  }
}
