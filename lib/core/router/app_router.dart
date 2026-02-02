import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/auth_provider.dart';
import '../../features/auth/presentation/user_management_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/inventory/presentation/inventory_screen.dart';
import '../../features/inventory/presentation/product_variants_screen.dart';
import '../../features/inventory/presentation/modifier_management_screen.dart';
import '../../features/inventory/presentation/low_stock_alerts_screen.dart';
import '../../features/pos/presentation/pos_screen.dart';
import '../../features/reports/presentation/reports_screen.dart';
import '../../features/tables/presentation/table_screen.dart';
import '../../features/tables/presentation/table_management_screen.dart';
import '../../features/settings/presentation/printer_settings_screen.dart';
import '../../features/settings/presentation/backup_restore_screen.dart';
import '../../features/customers/presentation/customer_screen.dart';
import '../../features/auth/presentation/attendance_logs_screen.dart';
import '../../features/auth/presentation/audit_journal_screen.dart';
import '../../features/inventory/presentation/inventory_logs_screen.dart';

// Create a key to maintain navigation state
final rootNavigatorKey = GlobalKey<NavigatorState>();

final goRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/login',
  redirect: (context, state) {
    // Redirect is synchronous here; auth checks handled in RouterListener
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
          path: 'table-management',
          builder: (context, state) => const TableManagementScreen(),
        ),
        GoRoute(
          path: 'inventory',
          builder: (context, state) => const InventoryScreen(),
        ),
        GoRoute(
          path: 'inventory/variants/:productId',
          builder: (context, state) {
            final productId = int.parse(state.pathParameters['productId']!);
            final productName = state.uri.queryParameters['name'] ?? 'Product';
            return ProductVariantsScreen(
              productId: productId,
              productName: productName,
            );
          },
        ),
        GoRoute(
          path: 'inventory/modifiers/:productId',
          builder: (context, state) {
            final productId = int.parse(state.pathParameters['productId']!);
            final productName = state.uri.queryParameters['name'] ?? 'Product';
            return ModifierManagementScreen(
              productId: productId,
              productName: productName,
            );
          },
        ),
        GoRoute(
          path: 'inventory/low-stock',
          builder: (context, state) => const LowStockAlertsScreen(),
        ),
        GoRoute(
          path: 'inventory/logs',
          builder: (context, state) => const InventoryLogsScreen(),
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
        GoRoute(
          path: 'settings/backup',
          builder: (context, state) => const BackupRestoreScreen(),
        ),
        GoRoute(
          path: 'settings/attendance',
          builder: (context, state) => const AttendanceLogsScreen(),
        ),
        GoRoute(
          path: 'settings/audit',
          builder: (context, state) => const AuditJournalScreen(),
        ),
        GoRoute(
          path: 'settings/users',
          builder: (context, state) => const UserManagementScreen(),
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
    String defaultHomeForRole(String? role) {
      if (role == 'cashier' || role == 'staff') {
        return '/pos';
      }
      return '/';
    }

    // Watch auth state and handle logout
    ref.listen(authProvider, (previous, next) {
      if (next == null && previous != null) {
        // User logged out, go to login
        context.go('/login');
      }
    });

    return child;
  }
}
