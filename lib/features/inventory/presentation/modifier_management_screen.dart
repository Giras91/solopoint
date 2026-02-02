import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import '../../../core/database/database.dart';
import '../../inventory/modifier_repository.dart';

class ModifierManagementScreen extends ConsumerStatefulWidget {
  final int productId;
  final String productName;

  const ModifierManagementScreen({
    super.key,
    required this.productId,
    required this.productName,
  });

  @override
  ConsumerState<ModifierManagementScreen> createState() =>
      _ModifierManagementScreenState();
}

class _ModifierManagementScreenState
    extends ConsumerState<ModifierManagementScreen> {
  @override
  Widget build(BuildContext context) {
    final modifiersStream = ref.watch(modifierRepositoryProvider)
        .watchModifiersWithItems(widget.productId);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Modifiers'),
            Text(
              widget.productName,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      body: StreamBuilder<List<ModifierWithItems>>(
        stream: modifiersStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final modifiers = snapshot.data ?? [];

          if (modifiers.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_circle_outline,
                      size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text('No modifiers yet',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text('Add modifiers like size, toppings, or add-ons',
                      style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: modifiers.length,
            itemBuilder: (context, index) {
              final modifierData = modifiers[index];
              return _ModifierCard(
                modifierData: modifierData,
                productId: widget.productId,
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddModifierDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Modifier'),
      ),
    );
  }

  void _showAddModifierDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _AddModifierDialog(productId: widget.productId),
    );
  }
}

class _ModifierCard extends ConsumerWidget {
  final ModifierWithItems modifierData;
  final int productId;

  const _ModifierCard({
    required this.modifierData,
    required this.productId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modifier = modifierData.modifier;
    final items = modifierData.items;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        title: Text(
          modifier.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          modifier.isMultipleChoice
              ? 'Multiple choice • ${items.length} items'
              : 'Single choice • ${items.length} items',
        ),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit, size: 20),
                  SizedBox(width: 8),
                  Text('Edit'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, size: 20, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
          onSelected: (value) {
            if (value == 'edit') {
              _showEditModifierDialog(context, ref, modifier);
            } else if (value == 'delete') {
              _deleteModifier(context, ref, modifier.id);
            }
          },
        ),
        children: [
          const Divider(height: 1),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return ListTile(
                title: Text(item.name),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.priceDelta >= 0
                          ? '+₱${item.priceDelta.toStringAsFixed(2)}'
                          : '-₱${(-item.priceDelta).toStringAsFixed(2)}',
                      style: TextStyle(
                        color: item.priceDelta >= 0
                            ? Colors.green
                            : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    PopupMenuButton(
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, size: 20),
                              SizedBox(width: 8),
                              Text('Edit'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, size: 20, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Delete',
                                  style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                      onSelected: (value) {
                        if (value == 'edit') {
                          _showEditItemDialog(
                              context, ref, modifier.id, item);
                        } else if (value == 'delete') {
                          _deleteItem(context, ref, item.id);
                        }
                      },
                    ),
                  ],
                ),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextButton.icon(
              onPressed: () =>
                  _showAddItemDialog(context, ref, modifier.id),
              icon: const Icon(Icons.add),
              label: const Text('Add Item'),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditModifierDialog(
      BuildContext context, WidgetRef ref, Modifier modifier) {
    showDialog(
      context: context,
      builder: (context) => _EditModifierDialog(modifier: modifier),
    );
  }

  void _deleteModifier(BuildContext context, WidgetRef ref, int modifierId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Modifier'),
        content: const Text(
            'Are you sure you want to delete this modifier group and all its items?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await ref
                  .read(modifierRepositoryProvider)
                  .deleteModifier(modifierId);
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Modifier deleted')),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showAddItemDialog(
      BuildContext context, WidgetRef ref, int modifierId) {
    showDialog(
      context: context,
      builder: (context) =>
          _AddModifierItemDialog(modifierId: modifierId),
    );
  }

  void _showEditItemDialog(
      BuildContext context, WidgetRef ref, int modifierId, ModifierItem item) {
    showDialog(
      context: context,
      builder: (context) => _EditModifierItemDialog(item: item),
    );
  }

  void _deleteItem(BuildContext context, WidgetRef ref, int itemId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item'),
        content: const Text('Are you sure you want to delete this item?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await ref
                  .read(modifierRepositoryProvider)
                  .deleteModifierItem(itemId);
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Item deleted')),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _AddModifierDialog extends ConsumerStatefulWidget {
  final int productId;

  const _AddModifierDialog({required this.productId});

  @override
  ConsumerState<_AddModifierDialog> createState() => _AddModifierDialogState();
}

class _AddModifierDialogState extends ConsumerState<_AddModifierDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool _isMultipleChoice = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Modifier Group'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'e.g., Size, Toppings, Add-ons',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Multiple Choice'),
              subtitle: const Text('Allow selecting multiple items'),
              value: _isMultipleChoice,
              onChanged: (value) {
                setState(() {
                  _isMultipleChoice = value;
                });
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saveModifier,
          child: const Text('Save'),
        ),
      ],
    );
  }

  void _saveModifier() async {
    if (!_formKey.currentState!.validate()) return;

    final companion = ModifiersCompanion(
      productId: drift.Value(widget.productId),
      name: drift.Value(_nameController.text),
      isMultipleChoice: drift.Value(_isMultipleChoice),
    );

    await ref.read(modifierRepositoryProvider).createModifier(companion);

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Modifier group created')),
      );
    }
  }
}

class _EditModifierDialog extends ConsumerStatefulWidget {
  final Modifier modifier;

  const _EditModifierDialog({required this.modifier});

  @override
  ConsumerState<_EditModifierDialog> createState() =>
      _EditModifierDialogState();
}

class _EditModifierDialogState extends ConsumerState<_EditModifierDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late bool _isMultipleChoice;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.modifier.name);
    _isMultipleChoice = widget.modifier.isMultipleChoice;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Modifier Group'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Multiple Choice'),
              subtitle: const Text('Allow selecting multiple items'),
              value: _isMultipleChoice,
              onChanged: (value) {
                setState(() {
                  _isMultipleChoice = value;
                });
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _updateModifier,
          child: const Text('Update'),
        ),
      ],
    );
  }

  void _updateModifier() async {
    if (!_formKey.currentState!.validate()) return;

    final updated = widget.modifier.copyWith(
      name: _nameController.text,
      isMultipleChoice: _isMultipleChoice,
    );

    await ref.read(modifierRepositoryProvider).updateModifier(updated);

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Modifier group updated')),
      );
    }
  }
}

class _AddModifierItemDialog extends ConsumerStatefulWidget {
  final int modifierId;

  const _AddModifierItemDialog({required this.modifierId});

  @override
  ConsumerState<_AddModifierItemDialog> createState() =>
      _AddModifierItemDialogState();
}

class _AddModifierItemDialogState
    extends ConsumerState<_AddModifierItemDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController(text: '0');

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Modifier Item'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'e.g., Large, Extra Cheese',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _priceController,
              decoration: const InputDecoration(
                labelText: 'Price Delta (₱)',
                hintText: '0 for no change, positive for extra cost',
                border: OutlineInputBorder(),
                prefixText: '₱ ',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a price';
                }
                if (double.tryParse(value) == null) {
                  return 'Please enter a valid number';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saveItem,
          child: const Text('Save'),
        ),
      ],
    );
  }

  void _saveItem() async {
    if (!_formKey.currentState!.validate()) return;

    final companion = ModifierItemsCompanion(
      modifierId: drift.Value(widget.modifierId),
      name: drift.Value(_nameController.text),
      priceDelta: drift.Value(double.parse(_priceController.text)),
    );

    await ref.read(modifierRepositoryProvider).createModifierItem(companion);

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item created')),
      );
    }
  }
}

class _EditModifierItemDialog extends ConsumerStatefulWidget {
  final ModifierItem item;

  const _EditModifierItemDialog({required this.item});

  @override
  ConsumerState<_EditModifierItemDialog> createState() =>
      _EditModifierItemDialogState();
}

class _EditModifierItemDialogState
    extends ConsumerState<_EditModifierItemDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _priceController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item.name);
    _priceController =
        TextEditingController(text: widget.item.priceDelta.toString());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Modifier Item'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _priceController,
              decoration: const InputDecoration(
                labelText: 'Price Delta (₱)',
                border: OutlineInputBorder(),
                prefixText: '₱ ',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a price';
                }
                if (double.tryParse(value) == null) {
                  return 'Please enter a valid number';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _updateItem,
          child: const Text('Update'),
        ),
      ],
    );
  }

  void _updateItem() async {
    if (!_formKey.currentState!.validate()) return;

    final updated = widget.item.copyWith(
      name: _nameController.text,
      priceDelta: double.parse(_priceController.text),
    );

    await ref.read(modifierRepositoryProvider).updateModifierItem(updated);

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item updated')),
      );
    }
  }
}
