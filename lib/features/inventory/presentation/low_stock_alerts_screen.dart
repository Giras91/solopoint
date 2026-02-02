import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../stock_alert_repository.dart';
import '../variant_repository.dart';

final lowStockItemsProvider = FutureProvider<List<LowStockItem>>((ref) async {
  return ref.watch(stockAlertRepositoryProvider).getLowStockItems();
});

class LowStockAlertsScreen extends ConsumerWidget {
  const LowStockAlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lowStockAsync = ref.watch(lowStockItemsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Low Stock Alerts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.refresh(lowStockItemsProvider),
          ),
        ],
      ),
      body: lowStockAsync.when(
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 64,
                    color: Colors.green[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'All stock levels are good',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.green[700],
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No items are below their threshold',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.orange[50],
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange[700]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${items.length} item${items.length == 1 ? '' : 's'} need restocking',
                        style: TextStyle(
                          color: Colors.orange[900],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final stockPercentage = item.currentStock / item.threshold;
                    final isCritical = stockPercentage <= 0.5;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      color: isCritical ? Colors.red[50] : Colors.orange[50],
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isCritical
                              ? Colors.red[100]
                              : Colors.orange[100],
                          child: Icon(
                            isCritical ? Icons.error : Icons.warning,
                            color: isCritical ? Colors.red[700] : Colors.orange[700],
                          ),
                        ),
                        title: Text(item.displayName),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  'Stock: ',
                                  style: TextStyle(color: Colors.grey[700]),
                                ),
                                Text(
                                  item.currentStock.toStringAsFixed(0),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isCritical ? Colors.red[700] : Colors.orange[700],
                                  ),
                                ),
                                Text(
                                  ' / ${item.threshold.toStringAsFixed(0)}',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            LinearProgressIndicator(
                              value: stockPercentage.clamp(0.0, 1.0),
                              backgroundColor: Colors.grey[200],
                              valueColor: AlwaysStoppedAnimation(
                                isCritical ? Colors.red : Colors.orange,
                              ),
                            ),
                          ],
                        ),
                        trailing: FilledButton(
                          onPressed: () => _restockItem(context, ref, item),
                          style: FilledButton.styleFrom(
                            backgroundColor:
                                isCritical ? Colors.red : Colors.orange,
                          ),
                          child: const Text('Restock'),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: $error'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.refresh(lowStockItemsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _restockItem(
      BuildContext context, WidgetRef ref, LowStockItem item) async {
    final quantityController = TextEditingController();
    final notesController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Restock ${item.displayName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Current stock: ${item.currentStock.toStringAsFixed(0)}',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: quantityController,
              decoration: const InputDecoration(
                labelText: 'Quantity to add',
                hintText: 'Enter amount',
              ),
              keyboardType: TextInputType.number,
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                hintText: 'Purchase order, supplier, etc.',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restock'),
          ),
        ],
      ),
    );

    if (result == true && context.mounted) {
      final quantity = double.tryParse(quantityController.text);
      if (quantity == null || quantity <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid quantity')),
        );
        return;
      }

      try {
        final variantRepo = ref.read(variantRepositoryProvider);
        if (item.variantId != null) {
          await variantRepo.adjustStock(
            item.variantId!,
            quantity,
            'restock',
            reference: 'Manual restock',
            notes: notesController.text.trim().isEmpty
                ? null
                : notesController.text.trim(),
          );
        } else {
          // Handle product stock adjustment (implement in inventory repository)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Product stock adjustment not yet implemented')),
          );
          return;
        }

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('${item.displayName} restocked successfully')),
          );
          // ignore: unused_result
          ref.refresh(lowStockItemsProvider);
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }
}
