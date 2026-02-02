import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/database/database.dart';
import 'add_edit_table_dialog.dart';
import 'table_providers.dart';

class TableScreen extends ConsumerWidget {
  const TableScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tablesAsync = ref.watch(tableListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tables (Dine-In)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () => context.go('/'),
          ),
        ],
      ),
      body: tablesAsync.when(
        data: (tables) {
          if (tables.isEmpty) {
            return const Center(child: Text('No tables. Add one!'));
          }
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 150,
              childAspectRatio: 1,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: tables.length,
            itemBuilder: (context, index) {
              return _TableCard(table: tables[index]);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (_) => const AddEditTableDialog(),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _TableCard extends ConsumerWidget {
  final RestaurantTable table;

  const _TableCard({required this.table});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOccupied = table.activeOrderId != null;

    return Card(
      elevation: 2,
      color: isOccupied ? Colors.red.shade100 : Colors.green.shade100,
      child: InkWell(
        onTap: () {
          // TODO: Open POS for this table
          context.go('/pos', extra: table);
        },
        onLongPress: () {
          showDialog(
            context: context,
            builder: (_) => AddEditTableDialog(table: table),
          );
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.table_restaurant,
              size: 48,
              color: isOccupied ? Colors.red : Colors.green,
            ),
            const SizedBox(height: 8),
            Text(
              table.name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text('Capacity: ${table.capacity}'),
            if (isOccupied)
              const Text(
                'Occupied',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              )
            else
              const Text(
                'Available',
                style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
              ),
          ],
        ),
      ),
    );
  }
}
