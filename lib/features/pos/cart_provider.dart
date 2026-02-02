import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/database.dart';

class CartItem {
  final Product product;
  final int quantity;

  CartItem({required this.product, required this.quantity});

  double get total => product.price * quantity;

  CartItem copyWith({Product? product, int? quantity}) {
    return CartItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
    );
  }
}

class CartState {
  final List<CartItem> items;

  CartState({this.items = const []});

  double get subtotal => items.fold(0, (sum, item) => sum + item.total);
  // We can add tax logic here later
  double get total => subtotal;

  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);
}

class CartNotifier extends StateNotifier<CartState> {
  CartNotifier() : super(CartState());

  void addToCart(Product product) {
    final existingIndex = state.items.indexWhere((item) => item.product.id == product.id);

    if (existingIndex >= 0) {
      // Increment quantity
      final newItems = List<CartItem>.from(state.items);
      final oldItem = newItems[existingIndex];
      newItems[existingIndex] = oldItem.copyWith(quantity: oldItem.quantity + 1);
      state = CartState(items: newItems);
    } else {
      // Add new item
      state = CartState(items: [...state.items, CartItem(product: product, quantity: 1)]);
    }
  }

  void removeFromCart(Product product) {
    final existingIndex = state.items.indexWhere((item) => item.product.id == product.id);
    if (existingIndex == -1) return;

    final newItems = List<CartItem>.from(state.items);
    final oldItem = newItems[existingIndex];

    if (oldItem.quantity > 1) {
      newItems[existingIndex] = oldItem.copyWith(quantity: oldItem.quantity - 1);
    } else {
      newItems.removeAt(existingIndex);
    }
    state = CartState(items: newItems);
  }

  void clearCart() {
    state = CartState(items: []);
  }

  // Load existing items (for loading saved order)
  // We need to fetch the Product object for each item. 
  // For simplicity here, assuming we can reconstruct it or fetch it separately.
  // Actually, UI usually does the fetching logic. Let's strictly accept CartItem list.
  void loadItems(List<CartItem> items) {
    state = CartState(items: items);
  }
}

final cartProvider = StateNotifierProvider<CartNotifier, CartState>((ref) {
  return CartNotifier();
});
