import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/database.dart';

class CartItem {
  final Product product;
  final ProductVariant? variant; // Optional variant
  final List<SelectedModifier> modifiers; // List of selected modifiers
  final int quantity;

  CartItem({
    required this.product,
    this.variant,
    this.modifiers = const [],
    required this.quantity,
  });

  // Get effective price (variant price if exists, otherwise product price)
  double get basePrice => variant?.price ?? product.price;
  
  // Calculate modifiers total
  double get modifiersTotal => modifiers.fold(0.0, (sum, mod) => sum + mod.priceDelta);
  
  // Unit price including modifiers
  double get unitPrice => basePrice + modifiersTotal;
  
  double get total => unitPrice * quantity;

  // Unique identifier for cart item (product + variant + modifiers combo)
  String get uniqueKey {
    final base = variant != null 
        ? '${product.id}_${variant!.id}' 
        : '${product.id}';
    
    if (modifiers.isEmpty) return base;
    
    final modifierKeys = modifiers.map((m) => '${m.modifierName}_${m.itemName}').join('_');
    return '${base}_$modifierKeys';
  }

  // Display name for the item
  String get displayName {
    var name = variant != null
        ? '${product.name} (${variant!.name})'
        : product.name;
    
    if (modifiers.isNotEmpty) {
      final modifierNames = modifiers.map((m) => m.itemName).join(', ');
      name += ' + $modifierNames';
    }
    
    return name;
  }

  CartItem copyWith({
    Product? product,
    ProductVariant? variant,
    List<SelectedModifier>? modifiers,
    int? quantity,
  }) {
    return CartItem(
      product: product ?? this.product,
      variant: variant ?? this.variant,
      modifiers: modifiers ?? this.modifiers,
      quantity: quantity ?? this.quantity,
    );
  }
}

/// Represents a selected modifier item
class SelectedModifier {
  final String modifierName; // e.g., "Size"
  final String itemName; // e.g., "Large"
  final double priceDelta; // e.g., 20.0

  SelectedModifier({
    required this.modifierName,
    required this.itemName,
    required this.priceDelta,
  });
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

  // Add product with optional variant and modifiers
  void addToCart(Product product, {ProductVariant? variant, List<SelectedModifier>? modifiers}) {
    final mods = modifiers ?? [];
    
    final item = CartItem(
      product: product,
      variant: variant,
      modifiers: mods,
      quantity: 1,
    );
    
    final uniqueKey = item.uniqueKey;
    
    final existingIndex = state.items.indexWhere(
      (item) => item.uniqueKey == uniqueKey
    );

    if (existingIndex >= 0) {
      // Increment quantity for exact same item (product + variant + modifiers)
      final newItems = List<CartItem>.from(state.items);
      final oldItem = newItems[existingIndex];
      newItems[existingIndex] = oldItem.copyWith(quantity: oldItem.quantity + 1);
      state = CartState(items: newItems);
    } else {
      // Add new item
      state = CartState(items: [
        ...state.items,
        item,
      ]);
    }
  }

  void removeFromCart(Product product, {ProductVariant? variant, List<SelectedModifier>? modifiers}) {
    final mods = modifiers ?? [];
    
    final item = CartItem(
      product: product,
      variant: variant,
      modifiers: mods,
      quantity: 1,
    );
    
    final uniqueKey = item.uniqueKey;
    
    final existingIndex = state.items.indexWhere(
      (item) => item.uniqueKey == uniqueKey
    );
    
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
