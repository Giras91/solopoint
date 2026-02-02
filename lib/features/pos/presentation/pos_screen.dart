import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/database/database.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../inventory/inventory_providers.dart';
import '../../orders/order_repository.dart';
import '../../inventory/inventory_repository.dart';
import '../cart_provider.dart';
import 'dialogs/checkout_dialog.dart';

class PosScreen extends ConsumerStatefulWidget {
  final RestaurantTable? table; // Optional table context

  const PosScreen({super.key, this.table});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  int? _selectedCategoryId;
  int? _currentOrderId; // Track if we are editing an existing order
  bool _isLoading = false;
  final _barcodeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.table?.activeOrderId != null) {
      _loadBackOrder(widget.table!.activeOrderId!);
    }
  }

  @override
  void dispose() {
    _barcodeController.dispose();
    super.dispose();
  }

  Future<void> _loadBackOrder(int orderId) async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(orderRepositoryProvider);
      final fullOrder = await repo.getOrderWithItems(orderId);
      
      if (fullOrder != null) {
        _currentOrderId = orderId;
        // We need to map OrderItem -> CartItem. 
        // This requires fetching the Product object to ensure we have current price/stock details.
        // For MVP, we will fetch all products once to map them. Efficient enough for small DB.
        final allProducts = await ref.read(inventoryRepositoryProvider).getAllProducts();
        
        final List<CartItem> cartItems = [];
        for (final item in fullOrder.items) {
          final product = allProducts.firstWhere((p) => p.id == item.productId, orElse: () => _createDummyProduct(item));
          cartItems.add(CartItem(product: product, quantity: item.quantity.toInt()));
        }

        ref.read(cartProvider.notifier).loadItems(cartItems);
      }
    } catch (e) {
      debugPrint('Error loading order: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Product _createDummyProduct(OrderItem item) {
    // Fallback if product was deleted from catalog but exists in order
    return Product(
      id: item.productId,
      name: item.productName,
      price: item.unitPrice,
      categoryId: null,
      sku: null,
      barcode: null,
      stockQuantity: 0,
      trackStock: false,
      isVariable: false,
      cost: 0,
    );
  }

  Future<void> _searchByBarcode(String barcode, WidgetRef ref) async {
    if (barcode.isEmpty) return;

    try {
      final repository = ref.read(inventoryRepositoryProvider);
      final products = await repository.getAllProducts();
      
      final product = products.firstWhere(
        (p) => p.barcode == barcode,
        orElse: () => throw Exception('Product not found'),
      );

      // Add to cart
      ref.read(cartProvider.notifier).addToCart(product);
      _barcodeController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${product.name} added to cart')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Product not found: $barcode'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.table == null 
          ? 'POS Terminal' 
          : 'Table ${widget.table!.name}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () => context.go('/'),
          )
        ],
      ),
      body: Row(
        children: [
          // Left Side: Product Catalog
          Expanded(
            flex: 3,
            child: Column(
              children: [
                // Barcode Search
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextField(
                    controller: _barcodeController,
                    decoration: InputDecoration(
                      labelText: 'Barcode Scanner',
                      hintText: 'Scan or enter barcode...',
                      prefixIcon: const Icon(Icons.qr_code_scanner),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _barcodeController.clear(),
                      ),
                      border: const OutlineInputBorder(),
                      filled: true,
                    ),
                    onSubmitted: (barcode) => _searchByBarcode(barcode, ref),
                  ),
                ),
                _CategorySelector(
                  selectedId: _selectedCategoryId,
                  onSelect: (id) => setState(() => _selectedCategoryId = id),
                ),
                Expanded(
                  child: _ProductGrid(selectedCategoryId: _selectedCategoryId),
                ),
              ],
            ),
          ),
          const VerticalDivider(width: 1),
          // Right Side: Cart
          Expanded(
            flex: 2,
            child: _CartSidebar(
               table: widget.table,
               currentOrderId: _currentOrderId, // Passed from State
            ),
          ),
        ],
      ),
    );
  }
}

class _CategorySelector extends ConsumerWidget {
  final int? selectedId;
  final ValueChanged<int?> onSelect;

  const _CategorySelector({required this.selectedId, required this.onSelect});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoryListProvider);

    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(vertical: 8),
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: categoriesAsync.when(
        data: (categories) {
          return ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: categories.length + 1, // +1 for "All"
            itemBuilder: (context, index) {
              if (index == 0) {
                final isSelected = selectedId == null;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: const Text('All'),
                    selected: isSelected,
                    onSelected: (_) => onSelect(null),
                  ),
                );
              }
              final category = categories[index - 1];
              final isSelected = selectedId == category.id;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(category.name),
                  selected: isSelected,
                  onSelected: (_) => onSelect(category.id),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const SizedBox(),
      ),
    );
  }
}

class _ProductGrid extends ConsumerWidget {
  final int? selectedCategoryId;

  const _ProductGrid({required this.selectedCategoryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productListProvider);

    return productsAsync.when(
      data: (allProducts) {
        final products = selectedCategoryId == null
            ? allProducts
            : allProducts.where((p) => p.categoryId == selectedCategoryId).toList();

        if (products.isEmpty) {
          return const Center(child: Text('No products found'));
        }

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 200,
            childAspectRatio: 1, // Square cards
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: products.length,
          itemBuilder: (context, index) {
            final product = products[index];
            return _ProductCard(product: product);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('Error: $e')),
    );
  }
}

class _ProductCard extends ConsumerWidget {
  final Product product;

  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          ref.read(cartProvider.notifier).addToCart(product);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Center(
                  child: Text(
                    product.name[0].toUpperCase(),
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    CurrencyFormatter.format(product.price),
                    style: TextStyle(color: Theme.of(context).colorScheme.primary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartSidebar extends ConsumerWidget {
  final RestaurantTable? table;
  final int? currentOrderId;

  const _CartSidebar({this.table, this.currentOrderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);

    return Column(
      children: [
        // Cart Header
        Container(
          padding: const EdgeInsets.all(16),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          width: double.infinity,
          child: Text(
            'Current Order',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        
        // Cart Items
        Expanded(
          child: cart.items.isEmpty
              ? const Center(child: Text('Cart is empty'))
              : ListView.separated(
                  itemCount: cart.items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = cart.items[index];
                    return ListTile(
                      title: Text(item.product.name),
                      subtitle: Text(
                          '${item.quantity} x ${CurrencyFormatter.format(item.product.price)}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            CurrencyFormatter.format(item.total),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: () {
                                ref.read(cartProvider.notifier).removeFromCart(item.product);
                            },
                          ),
                        ],
                      ),
                      onTap: () {
                          ref.read(cartProvider.notifier).addToCart(item.product);
                      },
                    );
                  },
                ),
        ),
        
        // Totals & Checkout
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total', style: Theme.of(context).textTheme.headlineSmall),
                  Text(
                    CurrencyFormatter.format(cart.total),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Hold Bill Button (Only if Table is selected)
              if (table != null && cart.items.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                         final orderRepo = ref.read(orderRepositoryProvider);
                         final orderItems = _mapCartToOrderItems(cart.items);
                         
                         try {
                           await orderRepo.saveOrder(
                             orderId: currentOrderId,
                             total: cart.total,
                             items: orderItems,
                             tableId: table!.id,
                           );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Order Saved (Hold)')),
                              );
                              ref.read(cartProvider.notifier).clearCart();
                              context.go('/tables'); // Return to tables
                            }
                         } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                            }
                         }
                      },
                      icon: const Icon(Icons.pause_circle_filled),
                      label: const Text('HOLD BILL / SEND TO KITCHEN'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ),

              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: cart.items.isEmpty
                      ? null
                      : () {
                          showDialog(
                            context: context,
                            builder: (context) => CheckoutDialog(
                              totalAmount: cart.total,
                              onConfirm: (cashReceived, method, customerId) async {
                                final orderRepo = ref.read(orderRepositoryProvider);
                                
                                final orderItems = _mapCartToOrderItems(cart.items);

                                try {
                                  // 1. Save/Update Order first
                                  final orderId = await orderRepo.saveOrder(
                                    orderId: currentOrderId,
                                    total: cart.total,
                                    items: orderItems,
                                    tableId: table?.id,
                                    status: 'completed', // Explicitly completing
                                    customerId: customerId, // Pass customer
                                  );

                                  // 2. Finalize (Clear Table etc) - also handles loyalty points
                                  await orderRepo.completeOrder(orderId, method);
                                  
                                  // 3. Print Receipt
                                  _printReceipt(
                                    ref: ref,
                                    orderId: orderId,
                                    items: orderItems,
                                    total: cart.total,
                                    cash: cashReceived,
                                    method: method,
                                  );

                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Order Completed!')),
                                    );
                                    ref.read(cartProvider.notifier).clearCart();
                                    if (table != null) context.go('/tables');
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Error: $e')),
                                    );
                                  }
                                }
                              },
                            ),
                          );
                        },
                  icon: const Icon(Icons.payment),
                  label: const Text('CHECKOUT'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<OrderItemData> _mapCartToOrderItems(List<CartItem> items) {
    return items.map((item) {
      return OrderItemData(
        productId: item.product.id,
        productName: item.product.name,
        quantity: item.quantity.toDouble(),
        unitPrice: item.product.price,
      );
    }).toList();
  }

  Future<void> _printReceipt({
    required WidgetRef ref,
    required int orderId,
    required List<OrderItemData> items,
    required double total,
    required double cash,
    required String method,
  }) async {
    // For now, just log - printer integration will be added later
    debugPrint('Receipt for Order #$orderId:');
    debugPrint('Total: \$$total');
    debugPrint('Payment Method: $method');
  }}