import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/database.dart';

final modifierRepositoryProvider = Provider<ModifierRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return ModifierRepository(db);
});

class ModifierRepository {
  final AppDatabase _db;

  ModifierRepository(this._db);

  // ============ Modifier Groups ============
  
  /// Watch all modifiers for a product
  Stream<List<Modifier>> watchModifiersByProduct(int productId) {
    return (_db.select(_db.modifiers)
          ..where((tbl) => tbl.productId.equals(productId)))
        .watch();
  }

  /// Get all modifiers for a product (one-time)
  Future<List<Modifier>> getModifiersByProduct(int productId) {
    return (_db.select(_db.modifiers)
          ..where((tbl) => tbl.productId.equals(productId)))
        .get();
  }

  /// Create a new modifier group
  Future<int> createModifier(ModifiersCompanion modifier) {
    return _db.into(_db.modifiers).insert(modifier);
  }

  /// Update an existing modifier group
  Future<int> updateModifier(Modifier modifier) {
    return (_db.update(_db.modifiers)
          ..where((tbl) => tbl.id.equals(modifier.id)))
        .write(modifier);
  }

  /// Delete a modifier group (cascades to items)
  Future<int> deleteModifier(int modifierId) async {
    // Delete all items first
    await (_db.delete(_db.modifierItems)
          ..where((tbl) => tbl.modifierId.equals(modifierId)))
        .go();
    
    // Then delete the modifier
    return (_db.delete(_db.modifiers)
          ..where((tbl) => tbl.id.equals(modifierId)))
        .go();
  }

  // ============ Modifier Items ============
  
  /// Watch all items for a modifier group
  Stream<List<ModifierItem>> watchModifierItems(int modifierId) {
    return (_db.select(_db.modifierItems)
          ..where((tbl) => tbl.modifierId.equals(modifierId)))
        .watch();
  }

  /// Get all items for a modifier group (one-time)
  Future<List<ModifierItem>> getModifierItems(int modifierId) {
    return (_db.select(_db.modifierItems)
          ..where((tbl) => tbl.modifierId.equals(modifierId)))
        .get();
  }

  /// Create a new modifier item
  Future<int> createModifierItem(ModifierItemsCompanion item) {
    return _db.into(_db.modifierItems).insert(item);
  }

  /// Update a modifier item
  Future<int> updateModifierItem(ModifierItem item) {
    return (_db.update(_db.modifierItems)
          ..where((tbl) => tbl.id.equals(item.id)))
        .write(item);
  }

  /// Delete a modifier item
  Future<int> deleteModifierItem(int itemId) {
    return (_db.delete(_db.modifierItems)
          ..where((tbl) => tbl.id.equals(itemId)))
        .go();
  }

  // ============ Combined Queries ============
  
  /// Get modifier with its items
  Future<ModifierWithItems> getModifierWithItems(int modifierId) async {
    final modifier = await (_db.select(_db.modifiers)
          ..where((tbl) => tbl.id.equals(modifierId)))
        .getSingle();
    
    final items = await getModifierItems(modifierId);
    
    return ModifierWithItems(modifier: modifier, items: items);
  }

  /// Watch all modifiers with items for a product
  Stream<List<ModifierWithItems>> watchModifiersWithItems(int productId) {
    return watchModifiersByProduct(productId).asyncMap((modifiers) async {
      final result = <ModifierWithItems>[];
      
      for (final modifier in modifiers) {
        final items = await getModifierItems(modifier.id);
        result.add(ModifierWithItems(modifier: modifier, items: items));
      }
      
      return result;
    });
  }
}

/// Data class for modifier with its items
class ModifierWithItems {
  final Modifier modifier;
  final List<ModifierItem> items;

  ModifierWithItems({
    required this.modifier,
    required this.items,
  });

  String get displayName => modifier.name;
  bool get isMultipleChoice => modifier.isMultipleChoice;
  int get itemCount => items.length;
}
