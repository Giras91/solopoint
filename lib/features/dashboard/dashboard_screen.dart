import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../auth/auth_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(authProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('SoloPoint POS'),
        actions: [
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
              
              // Grid of Actions
              Wrap(
                spacing: 20,
                runSpacing: 20,
                alignment: WrapAlignment.center,
                children: [
                  _DashboardCard(
                    icon: Icons.table_restaurant,
                    label: 'Tables',
                    onTap: () => context.go('/tables'),
                  ),
                  _DashboardCard(
                    icon: Icons.inventory,
                    label: 'Inventory',
                    onTap: () => context.go('/inventory'),
                  ),
                  _DashboardCard(
                    icon: Icons.shopping_cart,
                    label: 'POS Terminal',
                    onTap: () => context.go('/pos'),
                  ),
                  _DashboardCard(
                    icon: Icons.people,
                    label: 'Customers',
                    onTap: () => context.go('/customers'),
                  ),
                  _DashboardCard(
                    icon: Icons.bar_chart,
                    label: 'Reports',
                    onTap: () => context.go('/reports'),
                  ),
                  _DashboardCard(
                    icon: Icons.print,
                    label: 'Printer',
                    onTap: () => context.go('/settings/printer'),
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
