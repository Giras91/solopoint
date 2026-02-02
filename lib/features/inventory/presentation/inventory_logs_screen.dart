import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../auth/auth_provider.dart';
import '../../auth/admin_providers.dart';
import '../inventory_logs_providers.dart';

class InventoryLogsScreen extends ConsumerWidget {
  const InventoryLogsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(userRoleProvider);
    final isAdminOrManager = role == 'admin' || role == 'manager';

    if (!isAdminOrManager) {
      return Scaffold(
        appBar: AppBar(title: const Text('Inventory Logs')),
        body: const Center(child: Text('Admin/Manager access required')),
      );
    }

    final logsAsync = ref.watch(inventoryLogsProvider);
    final usersAsync = ref.watch(allUsersProvider);
    final productsAsync = ref.watch(productListStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Inventory Logs')),
      body: usersAsync.when(
        data: (users) {
          final userMap = {for (final u in users) u.id: u};
          return productsAsync.when(
            data: (products) {
              final productMap = {for (final p in products) p.id: p};
              return logsAsync.when(
                data: (logs) {
                  if (logs.isEmpty) {
                    return const Center(child: Text('No inventory logs yet'));
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: logs.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final log = logs[index];
                      final user = log.userId != null ? userMap[log.userId] : null;
                      final product = productMap[log.productId];
                      final timestamp = DateFormat('MMM dd, HH:mm').format(log.timestamp);
                      final change = log.changeAmount;
                      final changeLabel = change >= 0 ? '+${change.toStringAsFixed(2)}' : change.toStringAsFixed(2);

                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.inventory),
                          title: Text(product?.name ?? 'Product #${log.productId}'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Reason: ${log.reason}'),
                              Text('Change: $changeLabel'),
                              Text('User: ${user?.name ?? 'System'}'),
                              Text('Time: $timestamp'),
                              if (log.notes?.isNotEmpty == true) Text('Notes: ${log.notes}'),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(child: Text('Error: $error')),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text('Error: $error')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
    );
  }
}
