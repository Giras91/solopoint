import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/utils/currency_formatter.dart';
import '../auth/auth_provider.dart';
import 'dashboard_providers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(authProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final role = currentUser?.role;
    final isAdmin = role == 'admin';
    final isManager = role == 'manager';
    final isAdminOrManager = isAdmin || isManager;

    return Scaffold(
      appBar: AppBar(
        title: const Text('SoloPoint POS'),
        actions: [
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(dashboardStatsProvider);
            },
            tooltip: 'Refresh Stats',
          ),
          // User info and logout button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: colorScheme.primary,
                    child: Text(
                      currentUser?.name.isNotEmpty == true
                          ? currentUser!.name[0].toUpperCase()
                          : '?',
                      style: TextStyle(color: colorScheme.onPrimary),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentUser?.name ?? 'User',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      Text(
                        '${currentUser?.role}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: colorScheme.outline,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    icon: const Icon(Icons.logout),
                    onPressed: () {
                      ref.read(authProvider.notifier).logout();
                    },
                    tooltip: 'Logout',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.point_of_sale, size: 64, color: Colors.blue),
              const SizedBox(height: 20),
              Text(
                'Welcome to SoloPoint',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 10),
              const Text('Offline POS System'),
              const SizedBox(height: 40),
              
              // Stats Overview
              _StatsOverview(),
              const SizedBox(height: 40),
              
              // Grid of Actions
              Wrap(
                spacing: 20,
                runSpacing: 20,
                alignment: WrapAlignment.center,
                children: [
                  _DashboardCard(
                    icon: Icons.shopping_cart,
                    label: 'POS Terminal',
                    onTap: () => context.go('/pos'),
                  ),
                  _DashboardCard(
                    icon: Icons.table_restaurant,
                    label: 'Tables',
                    onTap: () => context.go('/table-management'),
                  ),
                  if (isAdminOrManager)
                    _DashboardCard(
                      icon: Icons.inventory,
                      label: 'Inventory',
                      onTap: () => context.go('/inventory'),
                    ),
                  if (isAdminOrManager)
                    _DashboardCard(
                      icon: Icons.warning,
                      label: 'Low Stock',
                      onTap: () => context.go('/inventory/low-stock'),
                    ),
                  if (isAdminOrManager)
                    _DashboardCard(
                      icon: Icons.receipt_long,
                      label: 'Inventory Logs',
                      onTap: () => context.go('/inventory/logs'),
                    ),
                  if (isAdminOrManager)
                    _DashboardCard(
                      icon: Icons.people,
                      label: 'Customers',
                      onTap: () => context.go('/customers'),
                    ),
                  if (isAdminOrManager)
                    _DashboardCard(
                      icon: Icons.bar_chart,
                      label: 'Reports',
                      onTap: () => context.go('/reports'),
                    ),
                  if (isAdminOrManager)
                    _DashboardCard(
                      icon: Icons.schedule,
                      label: 'Attendance',
                      onTap: () => context.go('/settings/attendance'),
                    ),
                  if (isAdmin)
                    _DashboardCard(
                      icon: Icons.security,
                      label: 'Audit Journal',
                      onTap: () => context.go('/settings/audit'),
                    ),
                  if (isAdmin)
                    _DashboardCard(
                      icon: Icons.admin_panel_settings,
                      label: 'Users',
                      onTap: () => context.go('/settings/users'),
                    ),
                  if (isAdminOrManager)
                    _DashboardCard(
                      icon: Icons.print,
                      label: 'Printer',
                      onTap: () => context.go('/settings/printer'),
                    ),
                  if (isAdmin)
                    _DashboardCard(
                      icon: Icons.backup,
                      label: 'Backup',
                      onTap: () => context.go('/settings/backup'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DashboardCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 150,
        height: 150,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

// Stats Overview Widget
class _StatsOverview extends ConsumerStatefulWidget {
  @override
  ConsumerState<_StatsOverview> createState() => _StatsOverviewState();
}

class _StatsOverviewState extends ConsumerState<_StatsOverview> {
  @override
  void initState() {
    super.initState();
    // Auto-refresh stats every 30 seconds
    Future.delayed(const Duration(seconds: 30), _autoRefresh);
  }

  void _autoRefresh() {
    if (mounted) {
      ref.invalidate(dashboardStatsProvider);
      Future.delayed(const Duration(seconds: 30), _autoRefresh);
    }
  }

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(dashboardStatsProvider);

    return statsAsync.when(
      data: (stats) {
        return Container(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            children: [
              // Last updated indicator
              Text(
                'Last updated: ${_formatTime(DateTime.now())}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
              const SizedBox(height: 8),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 4,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.3,
                children: [
                  _StatCard(
                    icon: Icons.attach_money,
                    label: 'Today\'s Sales',
                    value: CurrencyFormatter.format(stats.todaysSales),
                    color: Colors.green,
                    onTap: () => context.go('/reports'),
                  ),
                  _StatCard(
                    icon: Icons.receipt_long,
                    label: 'Orders',
                    value: '${stats.todaysOrders}',
                    color: Colors.blue,
                    onTap: () => context.go('/reports'),
                  ),
                  _StatCard(
                    icon: Icons.warning,
                    label: 'Low Stock',
                    value: '${stats.lowStockCount}',
                    color: stats.lowStockCount > 0 ? Colors.orange : Colors.green,
                    badge: stats.lowStockCount > 0 ? stats.lowStockCount : null,
                    onTap: () => context.go('/inventory/low-stock'),
                  ),
                  _StatCard(
                    icon: Icons.table_restaurant,
                    label: 'Active Tables',
                    value: '${stats.activeTablesCount}',
                    color: Colors.purple,
                    onTap: () => context.go('/table-management'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox(
        height: 120,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => const SizedBox(
        height: 120,
        child: Center(child: Text('Unable to load stats')),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

// Individual Stat Card
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final int? badge;
  final VoidCallback onTap;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Stack(
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 32,
                    color: color,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: color,
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              if (badge != null)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 24,
                      minHeight: 24,
                    ),
                    child: Center(
                      child: Text(
                        badge! > 99 ? '99+' : '$badge',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
