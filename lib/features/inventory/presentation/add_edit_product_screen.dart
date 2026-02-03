import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import '../../../../core/database/database.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../inventory_providers.dart';
import '../inventory_repository.dart';

class AddEditProductScreen extends ConsumerStatefulWidget {
  final Product? product;

  const AddEditProductScreen({super.key, this.product});

  @override
  ConsumerState<AddEditProductScreen> createState() => _AddEditProductScreenState();
}

class _AddEditProductScreenState extends ConsumerState<AddEditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late TextEditingController _costController;
  late TextEditingController _skuController;
  late TextEditingController _barcodeController;
  late TextEditingController _stockController;
  
  int? _selectedCategoryId;
  bool _trackStock = true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product?.name ?? '');
    _priceController = TextEditingController(text: widget.product?.price.toString() ?? '');
    _costController = TextEditingController(text: widget.product?.cost.toString() ?? '');
    _skuController = TextEditingController(text: widget.product?.sku ?? '');
    _barcodeController = TextEditingController(text: widget.product?.barcode ?? '');
    _stockController = TextEditingController(text: widget.product?.stockQuantity.toString() ?? '0');
    _selectedCategoryId = widget.product?.categoryId;
    _trackStock = widget.product?.trackStock ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _costController.dispose();
    _skuController.dispose();
    _barcodeController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedCategoryId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a category')),
        );
        return;
      }

      final repository = ref.read(inventoryRepositoryProvider);
      final name = _nameController.text.trim();
      final price = double.tryParse(_priceController.text) ?? 0.0;
      final cost = double.tryParse(_costController.text) ?? 0.0;
      final stock = double.tryParse(_stockController.text) ?? 0.0;
      final sku = _skuController.text.trim();
      final barcode = _barcodeController.text.trim();

      try {
        if (widget.product != null) {
          // Edit
          final updatedProduct = widget.product!.copyWith(
            name: name,
            price: price,
            cost: cost,
            stockQuantity: stock,
            sku: drift.Value(sku.isEmpty ? null : sku),
            barcode: drift.Value(barcode.isEmpty ? null : barcode),
            categoryId: drift.Value(_selectedCategoryId),
            trackStock: _trackStock,
          );
          await repository.updateProduct(updatedProduct);
        } else {
          // Add
          final newProduct = ProductsCompanion(
            name: drift.Value(name),
            price: drift.Value(price),
            cost: drift.Value(cost),
            stockQuantity: drift.Value(stock),
            sku: drift.Value(sku.isEmpty ? null : sku),
            barcode: drift.Value(barcode.isEmpty ? null : barcode),
            categoryId: drift.Value(_selectedCategoryId),
            trackStock: drift.Value(_trackStock),
          );
          await repository.addProduct(newProduct);
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
    final categoriesAsync = ref.watch(categoryListProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.product == null ? 'Add Product' : 'Edit Product'),
        actions: [
          IconButton(onPressed: _save, icon: const Icon(Icons.check)),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Product Name
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Product Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              // Category Dropdown
              categoriesAsync.when(
                data: (categories) {
                  return DropdownButtonFormField<int>(
                    initialValue: _selectedCategoryId,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                    ),
                    items: categories.map((cat) {
                      return DropdownMenuItem(
                        value: cat.id,
                        child: Text(cat.name),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedCategoryId = value;
                      });
                    },
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (e, s) => Text('Error loading categories: $e'),
              ),
              const SizedBox(height: 16),

              // Price & Cost Row
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _priceController,
                      decoration: InputDecoration(
                        labelText: 'Price',
                        prefixText: '${CurrencyFormatter.currencySymbol} ',
                        border: const OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _costController,
                      decoration: InputDecoration(
                        labelText: 'Cost',
                        prefixText: '${CurrencyFormatter.currencySymbol} ',
                        border: const OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // SKU
              TextFormField(
                controller: _skuController,
                decoration: const InputDecoration(
                  labelText: 'SKU (Optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // Barcode
              TextFormField(
                controller: _barcodeController,
                decoration: const InputDecoration(
                  labelText: 'Barcode (Optional)',
                  hintText: 'Scan or enter barcode',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.qr_code_scanner),
                ),
              ),
              const SizedBox(height: 16),

              // Stock
              SwitchListTile(
                title: const Text('Track Stock'),
                value: _trackStock,
                onChanged: (val) {
                  setState(() {
                    _trackStock = val;
                  });
                },
                contentPadding: EdgeInsets.zero,
              ),
              if (_trackStock)
                TextFormField(
                  controller: _stockController,
                  decoration: const InputDecoration(
                    labelText: 'Current Stock',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
