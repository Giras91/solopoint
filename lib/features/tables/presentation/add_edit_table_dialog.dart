import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import '../../../../core/database/database.dart';
import '../data/table_repository.dart';

class AddEditTableDialog extends ConsumerStatefulWidget {
  final RestaurantTable? table;

  const AddEditTableDialog({super.key, this.table});

  @override
  ConsumerState<AddEditTableDialog> createState() => _AddEditTableDialogState();
}

class _AddEditTableDialogState extends ConsumerState<AddEditTableDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _capacityController = TextEditingController(text: '4');

  @override
  void initState() {
    super.initState();
    if (widget.table != null) {
      _nameController.text = widget.table!.name;
      _capacityController.text = widget.table!.capacity.toString();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _capacityController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_formKey.currentState!.validate()) {
      final repository = ref.read(tableRepositoryProvider);
      final name = _nameController.text.trim();
      final capacity = int.tryParse(_capacityController.text) ?? 4;

      try {
        if (widget.table != null) {
          final updatedTable = widget.table!.copyWith(
            name: name,
            capacity: capacity,
          );
          await repository.updateTable(updatedTable);
        } else {
          final newTable = RestaurantTablesCompanion(
            name: drift.Value(name),
            capacity: drift.Value(capacity),
          );
          await repository.addTable(newTable);
        }
        if (mounted) Navigator.of(context).pop();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.table == null ? 'Add Table' : 'Edit Table'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Table Name (e.g. T1)',
                border: OutlineInputBorder(),
              ),
              validator: (value) =>
                  value == null || value.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _capacityController,
              decoration: const InputDecoration(
                labelText: 'Capacity',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
