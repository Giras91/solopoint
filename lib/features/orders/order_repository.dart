import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/database/database.dart';

final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return OrderRepository(db);
});

class OrderRepository {
  final AppDatabase _db;

  OrderRepository(this._db);

  /// Save a new order or update an existing one
  Future<int> saveOrder({
    int? orderId,
    required double total,
    required List<OrderItemData> items,
    int? tableId,
    int? customerId,
    String paymentMethod = 'cash',
    String status = 'pending',
  }) async {
    return _db.transaction(() async {
      int finalOrderId;

      if (orderId != null) {
        // Update existing order
        await _db.update(_db.orders).replace(Order(
          id: orderId,
          orderNumber: await _getOrderNumber(orderId),
          timestamp: DateTime.now(),
          subtotal: items.fold(0, (sum, item) => sum + item.total),
          tax: 0,
          discount: 0,
          total: total,
          status: status,
          paymentMethod: paymentMethod,
          tableId: tableId,
          customerId: customerId,
        ));
        finalOrderId = orderId;
        
        // Delete old items and re-insert
        await (_db.delete(_db.orderItems)..where((t) => t.orderId.equals(orderId))).go();
      } else {
        // Create new order
        finalOrderId = await _db.into(_db.orders).insert(OrdersCompanion(
          orderNumber: Value(_generateOrderNumber()),
          timestamp: Value(DateTime.now()),
          subtotal: Value(items.fold(0, (sum, item) => sum + item.total)),
          total: Value(total),
          paymentMethod: Value(paymentMethod),
          status: Value(status),
          tableId: Value(tableId),
          customerId: Value(customerId),
        ));
      }

      // Insert order items
      for (final item in items) {
        await _db.into(_db.orderItems).insert(OrderItemsCompanion(
          orderId: Value(finalOrderId),
          productId: Value(item.productId),
          productName: Value(item.productName),
          quantity: Value(item.quantity),
          unitPrice: Value(item.unitPrice),
          total: Value(item.total),
        ));

        // Update stock if tracking is enabled
        final product = await (_db.select(_db.products)
          ..where((p) => p.id.equals(item.productId)))
          .getSingleOrNull();
        
        if (product != null && product.trackStock) {
          final newStock = product.stockQuantity - item.quantity;
          await (_db.update(_db.products)..where((p) => p.id.equals(item.productId)))
              .write(ProductsCompanion(stockQuantity: Value(newStock)));
        }
      }

      return finalOrderId;
    });
  }

  /// Complete an order (save transaction, update table status if applicable)
  Future<void> completeOrder(int orderId, String paymentMethod) async {
    await _db.transaction(() async {
      // Update order status
      final order = await (_db.select(_db.orders)
        ..where((o) => o.id.equals(orderId)))
        .getSingle();

      await _db.update(_db.orders).replace(order.copyWith(status: 'completed'));

      // Create transaction record
      await _db.into(_db.transactions).insert(TransactionsCompanion(
        orderId: Value(orderId),
        amount: Value(order.total),
        method: Value(paymentMethod),
        status: const Value('completed'),
        timestamp: Value(DateTime.now()),
      ));

      // Update customer loyalty if customer is linked
      if (order.customerId != null) {
        final customer = await (_db.select(_db.customers)
          ..where((c) => c.id.equals(order.customerId!)))
          .getSingleOrNull();

        if (customer != null) {
          // Award loyalty points: 1 point per ₱10 spent
          final pointsEarned = (order.total / 10).floor();
          final newPoints = customer.loyaltyPoints + pointsEarned;
          final newTotalSpent = customer.totalSpent + order.total;

          await _db.update(_db.customers).replace(customer.copyWith(
            loyaltyPoints: newPoints,
            totalSpent: newTotalSpent,
          ));
        }
      }

      // Clear table's active order if applicable
      if (order.tableId != null) {
        final table = await (_db.select(_db.restaurantTables)
          ..where((t) => t.id.equals(order.tableId!)))
          .getSingleOrNull();

        if (table != null) {
          await _db.update(_db.restaurantTables).replace(
            table.copyWith(activeOrderId: const Value(null)),
          );
        }
      }
    });
  }

  /// Get an order with all its items
  Future<OrderWithItems?> getOrderWithItems(int orderId) async {
    final order = await (_db.select(_db.orders)
      ..where((o) => o.id.equals(orderId)))
      .getSingleOrNull();

    if (order == null) return null;

    final items = await (_db.select(_db.orderItems)
      ..where((i) => i.orderId.equals(orderId)))
      .get();

    return OrderWithItems(order: order, items: items);
  }

  /// Get order number for display
  Future<String> _getOrderNumber(int orderId) async {
    final order = await (_db.select(_db.orders)
      ..where((o) => o.id.equals(orderId)))
      .getSingle();
    return order.orderNumber;
  }

  /// Generate unique order number
  String _generateOrderNumber() {
    final now = DateTime.now();
    final formatter = DateFormat('yyyyMMdd-HHmmss');
    return 'ORD-${formatter.format(now)}';
  }

  // Create a new order with items transactionally
  Future<void> createOrder({
    required double total,
    required List<OrderItemData> items,
    String paymentMethod = 'cash',
  }) async {
    return _db.transaction(() async {
      // 1. Insert Order
      final orderId = await _db.into(_db.orders).insert(OrdersCompanion(
        orderNumber: Value(_generateOrderNumber()),
        timestamp: Value(DateTime.now()),
        subtotal: Value(total),
        total: Value(total),
        paymentMethod: Value(paymentMethod),
        status: const Value('completed'),
      ));

      // 2. Insert Order Items
      for (final item in items) {
        await _db.into(_db.orderItems).insert(OrderItemsCompanion(
          orderId: Value(orderId),
          productId: Value(item.productId),
          productName: Value(item.productName),
          quantity: Value(item.quantity),
          unitPrice: Value(item.unitPrice),
          total: Value(item.total),
        ));

        // 3. Update Stock (Decrement)
        final product = await (_db.select(_db.products)..where((p) => p.id.equals(item.productId))).getSingle();
        if (product.trackStock) {
          final newStock = product.stockQuantity - item.quantity;
          await (_db.update(_db.products)..where((p) => p.id.equals(item.productId)))
              .write(ProductsCompanion(stockQuantity: Value(newStock)));
        }
      }
    });
  }

  // --- Reporting Methods ---

  // Get total sales for a specific date range
  Future<double> getTotalSales(DateTime start, DateTime end) async {
    final query = _db.select(_db.orders)
      ..where((t) => t.timestamp.isBetweenValues(start, end))
      ..where((t) => t.status.equals('completed'));
    
    final orders = await query.get();
    return orders.fold<double>(0.0, (sum, order) => sum + order.total);
  }

  // Get recent orders
  Future<List<Order>> getRecentOrders({int limit = 10}) {
    return (_db.select(_db.orders)
          ..orderBy([(t) => OrderingTerm(expression: t.timestamp, mode: OrderingMode.desc)])
          ..limit(limit))
        .get();
  }

  // Get orders by date range
  Future<List<Order>> getOrdersByDateRange(DateTime start, DateTime end) {
    return (_db.select(_db.orders)
          ..where((t) => t.timestamp.isBetweenValues(start, end))
          ..where((t) => t.status.equals('completed'))
          ..orderBy([(t) => OrderingTerm(expression: t.timestamp, mode: OrderingMode.desc)]))
        .get();
  }

  // Get sales grouped by payment method
  Future<Map<String, double>> getSalesByPaymentMethod(DateTime start, DateTime end) async {
    final query = _db.select(_db.orders)
      ..where((t) => t.timestamp.isBetweenValues(start, end))
      ..where((t) => t.status.equals('completed'));

    final orders = await query.get();
    
    final Map<String, double> result = {};
    for (final order in orders) {
      result[order.paymentMethod] = (result[order.paymentMethod] ?? 0) + order.total;
    }
    return result;
  }

  // Get top selling products by quantity and revenue
  Future<List<ProductSalesData>> getTopSellingProducts(
    DateTime start,
    DateTime end, {
    int limit = 10,
  }) async {
    // Get all orders in the date range
    final orders = await (_db.select(_db.orders)
      ..where((t) => t.timestamp.isBetweenValues(start, end))
      ..where((t) => t.status.equals('completed')))
      .get();

    if (orders.isEmpty) return [];

    // Get all order items for these orders
    final orderIds = orders.map((o) => o.id).toList();
    final allItems = await (_db.select(_db.orderItems)
      ..where((item) => item.orderId.isIn(orderIds)))
      .get();

    // Group by product and calculate totals
    final Map<int, ProductSalesData> productStats = {};
    for (final item in allItems) {
      if (productStats.containsKey(item.productId)) {
        final existing = productStats[item.productId]!;
        productStats[item.productId] = ProductSalesData(
          productId: item.productId,
          productName: item.productName,
          totalQuantity: existing.totalQuantity + item.quantity,
          totalRevenue: existing.totalRevenue + item.total,
        );
      } else {
        productStats[item.productId] = ProductSalesData(
          productId: item.productId,
          productName: item.productName,
          totalQuantity: item.quantity,
          totalRevenue: item.total,
        );
      }
    }

    // Sort by quantity and take top N
    final sortedProducts = productStats.values.toList()
      ..sort((a, b) => b.totalQuantity.compareTo(a.totalQuantity));

    return sortedProducts.take(limit).toList();
  }

  /// Get sales grouped by category
  Future<Map<String, double>> getSalesByCategory(DateTime startDate, DateTime endDate) async {
    // Get all completed orders in date range
    final orders = await (_db.select(_db.orders)
      ..where((o) => 
        o.status.equals('completed') & 
        o.timestamp.isBiggerOrEqualValue(startDate) & 
        o.timestamp.isSmallerOrEqualValue(endDate)))
      .get();

    final Map<String, double> categorySales = {};

    // For each order, get items and their product categories
    for (final order in orders) {
      final items = await (_db.select(_db.orderItems)
        ..where((item) => item.orderId.equals(order.id)))
        .get();

      for (final item in items) {
        // Get product and its category
        final product = await (_db.select(_db.products)
          ..where((p) => p.id.equals(item.productId)))
          .getSingleOrNull();

        if (product != null && product.categoryId != null) {
          // Get category name
          final category = await (_db.select(_db.categories)
            ..where((c) => c.id.equals(product.categoryId!)))
            .getSingleOrNull();

          final categoryName = category?.name ?? 'Uncategorized';
          categorySales[categoryName] = (categorySales[categoryName] ?? 0) + item.total;
        } else {
          categorySales['Uncategorized'] = (categorySales['Uncategorized'] ?? 0) + item.total;
        }
      }
    }

    return categorySales;
  }
}

// Helper DTO for passing items to repository
class OrderItemData {
  final int productId;
  final String productName;
  final double quantity;
  final double unitPrice;

  OrderItemData({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
  });

  double get total => quantity * unitPrice;
}

// Helper class to return order with items
class OrderWithItems {
  final Order order;
  final List<OrderItem> items;

  OrderWithItems({required this.order, required this.items});
}

// Helper class for product sales data
class ProductSalesData {
  final int productId;
  final String productName;
  final double totalQuantity;
  final double totalRevenue;

  ProductSalesData({
    required this.productId,
    required this.productName,
    required this.totalQuantity,
    required this.totalRevenue,
  });
}
