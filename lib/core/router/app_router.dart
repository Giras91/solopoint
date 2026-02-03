import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/auth_provider.dart';
import '../../features/auth/presentation/user_management_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/dashboard/admin_dashboard_screen.dart';
import '../../features/inventory/presentation/inventory_screen.dart';
import '../../features/inventory/presentation/product_variants_screen.dart';
import '../../features/inventory/presentation/modifier_management_screen.dart';
import '../../features/inventory/presentation/low_stock_alerts_screen.dart';
import '../../features/forecasting/presentation/forecasting_screen.dart';
import '../../features/employee_performance/presentation/employee_performance_screen.dart';
import '../../features/feedback/presentation/feedback_screen.dart';
import '../../features/kds/presentation/kds_screen.dart';
import '../../features/pos/presentation/pos_screen.dart';
import '../../features/reports/presentation/reports_screen.dart';
import '../../features/reports/presentation/analytics_dashboard_screen.dart';
import '../../features/reports/presentation/report_export_screen.dart';
import '../../features/reports/presentation/profit_analytics_screen.dart';
import '../../features/tables/presentation/table_screen.dart';
import '../../features/tables/presentation/table_management_screen.dart';
import '../../features/settings/presentation/printer_settings_screen.dart';
import '../../features/settings/presentation/printer_setup_screen.dart';
import '../../features/backup/presentation/backup_settings_screen.dart';
import '../../features/settings/presentation/language_settings_screen.dart';
import '../../features/customers/presentation/customer_screen.dart';
import '../../features/auth/presentation/attendance_logs_screen.dart';
import '../../features/auth/presentation/audit_journal_screen.dart';
import '../../features/inventory/presentation/inventory_logs_screen.dart';
import '../../features/stores/presentation/store_management_screen.dart';
import '../../features/stores/presentation/sync_control_screen.dart';

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
    
    // Admin Dashboard (restricted to admin/manager)
    GoRoute(
      path: '/admin',
      builder: (context, state) => const AdminDashboardScreen(),
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
          path: 'kitchen',
          builder: (context, state) => const KdsScreen(),
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
          path: 'forecasting',
          builder: (context, state) => const ForecastingScreen(),
        ),
        GoRoute(
          path: 'employees/performance',
          builder: (context, state) => const EmployeePerformanceScreen(),
        ),
        GoRoute(
          path: 'feedback',
          builder: (context, state) => const FeedbackScreen(),
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
          path: 'analytics',
          builder: (context, state) => const AnalyticsDashboardScreen(),
        ),
        GoRoute(
          path: 'analytics/profit',
          builder: (context, state) => const ProfitAnalyticsScreen(),
        ),
        GoRoute(
          path: 'reports/export',
          builder: (context, state) => const ReportExportScreen(),
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
          path: 'settings/printer/setup',
          builder: (context, state) => const PrinterSetupScreen(),
        ),
        GoRoute(
          path: 'settings/backup',
          builder: (context, state) => const BackupSettingsScreen(),
        ),
        GoRoute(
          path: 'settings/language',
          builder: (context, state) => const LanguageSettingsScreen(),
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
        GoRoute(
          path: 'settings/stores',
          builder: (context, state) => const StoreManagementScreen(),
        ),
        GoRoute(
          path: 'settings/sync',
          builder: (context, state) => const SyncControlScreen(),
        ),
      ],
    ),
  ],
);

/// Router Listener for handling auth state changes and role-based navigation
class RouterListener extends ConsumerWidget {
  final Widget child;

  const RouterListener({
    required this.child,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    /// Determine the home route based on user role
    String getHomeRouteForRole(String? role) {
      if (role == null) return '/login';
      
      switch (role.toLowerCase()) {
        case 'admin':
        case 'manager':
          return '/admin';
        case 'cashier':
        case 'staff':
          return '/pos';
        default:
          return '/';
      }
    }

    // Watch auth state and handle logout
    ref.listen(authProvider, (previous, next) {
      if (next == null && previous != null) {
        // User logged out, go to login
        context.go('/login');
      } else if (next != null && previous == null) {
        // User just logged in, redirect to appropriate home based on role
        final homeRoute = getHomeRouteForRole(next.role);
        context.go(homeRoute);
      }
    });

    return child;
  }
}
