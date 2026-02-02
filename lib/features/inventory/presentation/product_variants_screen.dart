import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import '../../../core/database/database.dart';
import '../variant_repository.dart';

class ProductVariantsScreen extends ConsumerStatefulWidget {
  final int productId;
  final String productName;

  const ProductVariantsScreen({
    super.key,
    required this.productId,
    required this.productName,
  });

  @override
  ConsumerState<ProductVariantsScreen> createState() =>
      _ProductVariantsScreenState();
}

class _ProductVariantsScreenState extends ConsumerState<ProductVariantsScreen> {
  @override
  Widget build(BuildContext context) {
    final variantsStream = ref
        .watch(variantRepositoryProvider)
        .watchVariantsByProduct(widget.productId);

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.productName} - Variants'),
      ),
      body: StreamBuilder<List<ProductVariant>>(
        stream: variantsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final variants = snapshot.data ?? [];

          if (variants.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No variants yet',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add variants like sizes or colors',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[500],
                        ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: variants.length,
            itemBuilder: (context, index) {
              final variant = variants[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: variant.isActive
                        ? Colors.green[100]
                        : Colors.grey[300],
                    child: Icon(
                      Icons.style,
                      color: variant.isActive ? Colors.green[700] : Colors.grey[600],
                    ),
                  ),
                  title: Text(variant.name),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Price: ₱${variant.price.toStringAsFixed(2)}'),
                      Text('Stock: ${variant.stockQuantity.toStringAsFixed(0)}'),
                      if (variant.sku != null) Text('SKU: ${variant.sku}'),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _showVariantDialog(variant: variant),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => _deleteVariant(variant.id),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showVariantDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Add Variant'),
      ),
    );
  }

  Future<void> _showVariantDialog({ProductVariant? variant}) async {
    final nameController = TextEditingController(text: variant?.name ?? '');
    final skuController = TextEditingController(text: variant?.sku ?? '');
    final barcodeController = TextEditingController(text: variant?.barcode ?? '');
    final priceController = TextEditingController(
        text: variant?.price.toString() ?? '');
    final costController = TextEditingController(
        text: variant?.cost?.toString() ?? '');
    final stockController = TextEditingController(
        text: variant?.stockQuantity.toString() ?? '0');

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(variant == null ? 'Add Variant' : 'Edit Variant'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Name *',
                  hintText: 'e.g., Small, Large, Red',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: skuController,
                decoration: const InputDecoration(
                  labelText: 'SKU',
                  hintText: 'Optional',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: barcodeController,
                decoration: const InputDecoration(
                  labelText: 'Barcode',
                  hintText: 'Optional',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: priceController,
                decoration: const InputDecoration(
                  labelText: 'Price *',
                  prefixText: '₱',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: costController,
                decoration: const InputDecoration(
                  labelText: 'Cost',
                  prefixText: '₱',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: stockController,
                decoration: const InputDecoration(
                  labelText: 'Stock Quantity',
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
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

    if (result == true) {
      final name = nameController.text.trim();
      final price = double.tryParse(priceController.text) ?? 0;

      if (name.isEmpty || price <= 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Name and price are required')),
          );
        }
        return;
      }

      final companion = ProductVariantsCompanion(
        productId: drift.Value(widget.productId),
        name: drift.Value(name),
        sku: drift.Value(skuController.text.trim().isEmpty
            ? null
            : skuController.text.trim()),
        barcode: drift.Value(barcodeController.text.trim().isEmpty
            ? null
            : barcodeController.text.trim()),
        price: drift.Value(price),
        cost: drift.Value(double.tryParse(costController.text)),
        stockQuantity: drift.Value(double.tryParse(stockController.text) ?? 0),
      );

      try {
        if (variant == null) {
          await ref.read(variantRepositoryProvider).createVariant(companion);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Variant created')),
            );
          }
        } else {
          await ref
              .read(variantRepositoryProvider)
              .updateVariant(variant.id, companion);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Variant updated')),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  Future<void> _deleteVariant(int variantId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Variant'),
        content: const Text('Are you sure you want to delete this variant?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ref.read(variantRepositoryProvider).deleteVariant(variantId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Variant deleted')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }
}
