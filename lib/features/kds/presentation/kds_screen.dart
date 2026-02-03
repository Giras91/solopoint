import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../kds_providers.dart';
import '../kds_repository.dart';

class KdsScreen extends ConsumerWidget {
  const KdsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(kitchenStatusFilterProvider);
    final ordersAsync = ref.watch(kitchenOrdersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kitchen Display'),
      ),
      body: Column(
        children: [
          _buildFilterChips(ref, filter),
          Expanded(
            child: ordersAsync.when(
              data: (orders) => _buildOrderList(context, ref, orders, filter),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, st) => Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(WidgetRef ref, KitchenStatusFilter current) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Wrap(
        spacing: 8,
        children: KitchenStatusFilter.values.map((filter) {
          return ChoiceChip(
            label: Text(_filterLabel(filter)),
            selected: filter == current,
            onSelected: (_) => ref.read(kitchenStatusFilterProvider.notifier).state = filter,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildOrderList(
    BuildContext context,
    WidgetRef ref,
    List<KitchenOrder> orders,
    KitchenStatusFilter filter,
  ) {
    final filtered = orders.where((order) {
      switch (filter) {
        case KitchenStatusFilter.pending:
          return order.order.status == 'pending';
        case KitchenStatusFilter.inProgress:
          return order.order.status == 'in_progress';
        case KitchenStatusFilter.ready:
          return order.order.status == 'ready';
        case KitchenStatusFilter.all:
          return true;
      }
    }).toList();

    if (filtered.isEmpty) {
      return const Center(child: Text('No kitchen orders.'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final kitchenOrder = filtered[index];
        return _orderCard(context, ref, kitchenOrder);
      },
    );
  }

  Widget _orderCard(BuildContext context, WidgetRef ref, KitchenOrder kitchenOrder) {
    final order = kitchenOrder.order;
    final timeText = DateFormat('hh:mm a').format(order.timestamp);
    final tableText = kitchenOrder.tableName != null ? 'Table ${kitchenOrder.tableName}' : 'Walk-in';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    order.orderNumber,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                Text(timeText, style: const TextStyle(color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 4),
            Text(tableText, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            ...kitchenOrder.items.map((item) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Text('${item.quantity.toStringAsFixed(1)}x', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(item.productName)),
                    if (item.note != null && item.note!.isNotEmpty)
                      const Icon(Icons.sticky_note_2, size: 16, color: Colors.orange),
                  ],
                ),
              );
            }),
            const SizedBox(height: 12),
            Row(
              children: [
                _statusChip(order.status),
                const Spacer(),
                _actionButton(
                  label: 'Start',
                  enabled: order.status == 'pending',
                  color: Colors.blue,
                  onPressed: () => _setStatus(ref, order.id, 'in_progress'),
                ),
                const SizedBox(width: 8),
                _actionButton(
                  label: 'Ready',
                  enabled: order.status != 'ready',
                  color: Colors.green,
                  onPressed: () => _setStatus(ref, order.id, 'ready'),
                ),
                const SizedBox(width: 8),
                _actionButton(
                  label: 'Back',
                  enabled: order.status != 'pending',
                  color: Colors.grey,
                  onPressed: () => _setStatus(ref, order.id, 'pending'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String status) {
    return Chip(
      label: Text(_statusLabel(status)),
      backgroundColor: _statusColor(status).withOpacity(0.2),
      labelStyle: TextStyle(color: _statusColor(status), fontWeight: FontWeight.bold),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'in_progress':
        return Colors.blue;
      case 'ready':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'in_progress':
        return 'In Progress';
      case 'ready':
        return 'Ready';
      default:
        return status;
    }
  }

  String _filterLabel(KitchenStatusFilter filter) {
    switch (filter) {
      case KitchenStatusFilter.all:
        return 'All';
      case KitchenStatusFilter.pending:
        return 'Pending';
      case KitchenStatusFilter.inProgress:
        return 'In Progress';
      case KitchenStatusFilter.ready:
        return 'Ready';
    }
  }

  Widget _actionButton({
    required String label,
    required bool enabled,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      onPressed: enabled ? onPressed : null,
      style: ElevatedButton.styleFrom(backgroundColor: color),
      child: Text(label),
    );
  }

  Future<void> _setStatus(WidgetRef ref, int orderId, String status) async {
    await ref.read(kdsRepositoryProvider).updateOrderStatus(orderId, status);
  }
}
