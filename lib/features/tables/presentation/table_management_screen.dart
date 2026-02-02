import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:drift/drift.dart' as drift;
import '../../../core/database/database.dart';
import '../table_repository.dart';

final tableStatusProvider = StreamProvider<List<TableStatus>>((ref) {
  return ref.watch(tableRepositoryProvider).watchAllTableStatuses();
});

class TableManagementScreen extends ConsumerWidget {
  const TableManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tableStatusAsync = ref.watch(tableStatusProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Table Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddTableDialog(context, ref),
          ),
        ],
      ),
      body: tableStatusAsync.when(
        data: (tableStatuses) {
          if (tableStatuses.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.table_bar_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No tables configured',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => _createDefaultTables(context, ref),
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('Create Default Tables'),
                  ),
                ],
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.2,
            ),
            itemCount: tableStatuses.length,
            itemBuilder: (context, index) {
              final status = tableStatuses[index];
              return _TableCard(status: status);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('Error: $error'),
        ),
      ),
    );
  }

  Future<void> _createDefaultTables(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(tableRepositoryProvider).createDefaultTables();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Created 12 default tables')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _showAddTableDialog(BuildContext context, WidgetRef ref) async {
    final nameController = TextEditingController();
    final capacityController = TextEditingController(text: '4');

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Table'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Table Name',
                hintText: 'e.g., Table 1, VIP Room',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: capacityController,
              decoration: const InputDecoration(
                labelText: 'Capacity',
                hintText: 'Number of seats',
              ),
              keyboardType: TextInputType.number,
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
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result == true && context.mounted) {
      final name = nameController.text.trim();
      final capacity = int.tryParse(capacityController.text) ?? 4;

      if (name.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Table name is required')),
        );
        return;
      }

      try {
        await ref.read(tableRepositoryProvider).createTable(
              RestaurantTablesCompanion(
                name: drift.Value(name),
                capacity: drift.Value(capacity),
              ),
            );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Table added')),
          );
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

class _TableCard extends ConsumerWidget {
  final TableStatus status;

  const _TableCard({required this.status});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final table = status.table;
    final isOccupied = status.isOccupied;

    return Card(
      color: isOccupied ? Colors.orange[50] : Colors.green[50],
      child: InkWell(
        onTap: () => _onTableTap(context, ref),
        onLongPress: () => _showTableOptions(context, ref),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.table_restaurant,
                size: 48,
                color: isOccupied ? Colors.orange[700] : Colors.green[700],
              ),
              const SizedBox(height: 8),
              Text(
                table.name,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                status.statusText,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isOccupied ? Colors.orange[900] : Colors.green[900],
                    ),
              ),
              if (isOccupied && status.orderTotal != null) ...[
                const SizedBox(height: 4),
                Text(
                  '₱${status.orderTotal!.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '${table.capacity}',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onTableTap(BuildContext context, WidgetRef ref) async {
    if (status.isOccupied && status.activeOrder != null) {
      // Open order for the table
      context.push('/orders/${status.activeOrder!.id}');
    } else {
      // Create new order for the table
      context.push('/pos?tableId=${status.table.id}');
    }
  }

  Future<void> _showTableOptions(BuildContext context, WidgetRef ref) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit Table'),
              onTap: () => Navigator.pop(context, 'edit'),
            ),
            if (status.isOccupied)
              ListTile(
                leading: const Icon(Icons.clear),
                title: const Text('Clear Table'),
                onTap: () => Navigator.pop(context, 'clear'),
              ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete Table', style: TextStyle(color: Colors.red)),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );

    if (choice == 'edit' && context.mounted) {
      _showEditTableDialog(context, ref);
    } else if (choice == 'clear' && context.mounted) {
      _clearTable(context, ref);
    } else if (choice == 'delete' && context.mounted) {
      _deleteTable(context, ref);
    }
  }

  Future<void> _showEditTableDialog(BuildContext context, WidgetRef ref) async {
    final nameController = TextEditingController(text: status.table.name);
    final capacityController =
        TextEditingController(text: status.table.capacity.toString());

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Table'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Table Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: capacityController,
              decoration: const InputDecoration(labelText: 'Capacity'),
              keyboardType: TextInputType.number,
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
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == true && context.mounted) {
      try {
        await ref.read(tableRepositoryProvider).updateTable(
              status.table.id,
              RestaurantTablesCompanion(
                name: drift.Value(nameController.text.trim()),
                capacity: drift.Value(int.tryParse(capacityController.text) ?? 4),
              ),
            );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Table updated')),
          );
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

  Future<void> _clearTable(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Table'),
        content: const Text('Remove the active order from this table?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      try {
        await ref.read(tableRepositoryProvider).clearTable(status.table.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Table cleared')),
          );
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

  Future<void> _deleteTable(BuildContext context, WidgetRef ref) async {
    if (status.isOccupied) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot delete occupied table')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Table'),
        content: const Text('Are you sure you want to delete this table?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      try {
        await ref.read(tableRepositoryProvider).deleteTable(status.table.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Table deleted')),
          );
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
