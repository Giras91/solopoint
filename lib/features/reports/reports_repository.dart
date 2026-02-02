import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import '../../core/database/database.dart';

final reportsRepositoryProvider = Provider<ReportsRepository>((ref) {
  final database = ref.watch(databaseProvider);
  return ReportsRepository(database);
});

class ReportsRepository {
  final AppDatabase _db;

  ReportsRepository(this._db);

  // Sales summary for date range
  Future<SalesSummary> getSalesSummary({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final query = '''
      SELECT 
        COUNT(*) as orderCount,
        SUM(total) as totalSales,
        SUM(subtotal) as subtotal,
        SUM(tax) as totalTax,
        SUM(discount) as totalDiscount,
        AVG(total) as averageOrderValue
      FROM orders
      WHERE timestamp >= ? AND timestamp <= ? AND status = 'completed'
    ''';

    final result = await _db.customSelect(
      query,
      variables: [
        Variable.withDateTime(startDate),
        Variable.withDateTime(endDate),
      ],
    ).getSingle();

    return SalesSummary(
      orderCount: result.read<int>('orderCount'),
      totalSales: result.readNullable<double>('totalSales') ?? 0.0,
      subtotal: result.readNullable<double>('subtotal') ?? 0.0,
      totalTax: result.readNullable<double>('totalTax') ?? 0.0,
      totalDiscount: result.readNullable<double>('totalDiscount') ?? 0.0,
      averageOrderValue: result.readNullable<double>('averageOrderValue') ?? 0.0,
      startDate: startDate,
      endDate: endDate,
    );
  }

  // Top selling products
  Future<List<TopSellingProduct>> getTopSellingProducts({
    required DateTime startDate,
    required DateTime endDate,
    int limit = 10,
  }) async {
    final query = '''
      SELECT 
        oi.productId,
        oi.productName,
        oi.variantName,
        SUM(oi.quantity) as totalQuantity,
        SUM(oi.total) as totalRevenue,
        COUNT(DISTINCT oi.orderId) as orderCount
      FROM order_items oi
      INNER JOIN orders o ON oi.orderId = o.id
      WHERE o.timestamp >= ? AND o.timestamp <= ? AND o.status = 'completed'
      GROUP BY oi.productId, oi.variantId
      ORDER BY totalRevenue DESC
      LIMIT ?
    ''';

    final result = await _db.customSelect(
      query,
      variables: [
        Variable.withDateTime(startDate),
        Variable.withDateTime(endDate),
        Variable.withInt(limit),
      ],
    ).get();

    return result
        .map((row) => TopSellingProduct(
              productId: row.read<int>('productId'),
              productName: row.read<String>('productName'),
              variantName: row.readNullable<String>('variantName'),
              totalQuantity: row.read<double>('totalQuantity'),
              totalRevenue: row.read<double>('totalRevenue'),
              orderCount: row.read<int>('orderCount'),
            ))
        .toList();
  }

  // Payment method breakdown
  Future<List<PaymentMethodBreakdown>> getPaymentMethodBreakdown({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final query = '''
      SELECT 
        paymentMethod,
        COUNT(*) as orderCount,
        SUM(total) as totalAmount
      FROM orders
      WHERE timestamp >= ? AND timestamp <= ? AND status = 'completed'
      GROUP BY paymentMethod
      ORDER BY totalAmount DESC
    ''';

    final result = await _db.customSelect(
      query,
      variables: [
        Variable.withDateTime(startDate),
        Variable.withDateTime(endDate),
      ],
    ).get();

    return result
        .map((row) => PaymentMethodBreakdown(
              paymentMethod: row.read<String>('paymentMethod'),
              orderCount: row.read<int>('orderCount'),
              totalAmount: row.read<double>('totalAmount'),
            ))
        .toList();
  }

  // Sales by category
  Future<List<CategorySales>> getSalesByCategory({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final query = '''
      SELECT 
        c.id as categoryId,
        c.name as categoryName,
        SUM(oi.total) as totalRevenue,
        SUM(oi.quantity) as totalQuantity,
        COUNT(DISTINCT oi.orderId) as orderCount
      FROM order_items oi
      INNER JOIN orders o ON oi.orderId = o.id
      INNER JOIN products p ON oi.productId = p.id
      LEFT JOIN categories c ON p.categoryId = c.id
      WHERE o.timestamp >= ? AND o.timestamp <= ? AND o.status = 'completed'
      GROUP BY c.id
      ORDER BY totalRevenue DESC
    ''';

    final result = await _db.customSelect(
      query,
      variables: [
        Variable.withDateTime(startDate),
        Variable.withDateTime(endDate),
      ],
    ).get();

    return result
        .map((row) => CategorySales(
              categoryId: row.readNullable<int>('categoryId'),
              categoryName: row.readNullable<String>('categoryName') ?? 'Uncategorized',
              totalRevenue: row.read<double>('totalRevenue'),
              totalQuantity: row.read<double>('totalQuantity'),
              orderCount: row.read<int>('orderCount'),
            ))
        .toList();
  }

  // Daily sales chart data
  Future<List<DailySales>> getDailySales({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final query = '''
      SELECT 
        DATE(timestamp) as date,
        COUNT(*) as orderCount,
        SUM(total) as totalSales
      FROM orders
      WHERE timestamp >= ? AND timestamp <= ? AND status = 'completed'
      GROUP BY DATE(timestamp)
      ORDER BY date ASC
    ''';

    final result = await _db.customSelect(
      query,
      variables: [
        Variable.withDateTime(startDate),
        Variable.withDateTime(endDate),
      ],
    ).get();

    return result
        .map((row) => DailySales(
              date: DateTime.parse(row.read<String>('date')),
              orderCount: row.read<int>('orderCount'),
              totalSales: row.read<double>('totalSales'),
            ))
        .toList();
  }

  // Hourly sales distribution
  Future<List<HourlySales>> getHourlySales({
    required DateTime date,
  }) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final query = '''
      SELECT 
        CAST(strftime('%H', timestamp) AS INTEGER) as hour,
        COUNT(*) as orderCount,
        SUM(total) as totalSales
      FROM orders
      WHERE timestamp >= ? AND timestamp < ? AND status = 'completed'
      GROUP BY hour
      ORDER BY hour ASC
    ''';

    final result = await _db.customSelect(
      query,
      variables: [
        Variable.withDateTime(startOfDay),
        Variable.withDateTime(endOfDay),
      ],
    ).get();

    return result
        .map((row) => HourlySales(
              hour: row.read<int>('hour'),
              orderCount: row.read<int>('orderCount'),
              totalSales: row.read<double>('totalSales'),
            ))
        .toList();
  }

  // Customer report
  Future<List<CustomerReport>> getCustomerReport({
    required DateTime startDate,
    required DateTime endDate,
    int limit = 20,
  }) async {
    final query = '''
      SELECT 
        c.id,
        c.name,
        c.phone,
        c.totalSpent,
        c.loyaltyPoints,
        COUNT(o.id) as orderCount,
        MAX(o.timestamp) as lastOrderDate
      FROM customers c
      LEFT JOIN orders o ON c.id = o.customerId 
        AND o.timestamp >= ? AND o.timestamp <= ? 
        AND o.status = 'completed'
      GROUP BY c.id
      HAVING orderCount > 0
      ORDER BY c.totalSpent DESC
      LIMIT ?
    ''';

    final result = await _db.customSelect(
      query,
      variables: [
        Variable.withDateTime(startDate),
        Variable.withDateTime(endDate),
        Variable.withInt(limit),
      ],
    ).get();

    return result
        .map((row) => CustomerReport(
              customerId: row.read<int>('id'),
              name: row.read<String>('name'),
              phone: row.readNullable<String>('phone'),
              totalSpent: row.read<double>('totalSpent'),
              loyaltyPoints: row.read<int>('loyaltyPoints'),
              orderCount: row.read<int>('orderCount'),
              lastOrderDate: row.readNullable<DateTime>('lastOrderDate'),
            ))
        .toList();
  }
}

// Data classes for reports
class SalesSummary {
  final int orderCount;
  final double totalSales;
  final double subtotal;
  final double totalTax;
  final double totalDiscount;
  final double averageOrderValue;
  final DateTime startDate;
  final DateTime endDate;

  SalesSummary({
    required this.orderCount,
    required this.totalSales,
    required this.subtotal,
    required this.totalTax,
    required this.totalDiscount,
    required this.averageOrderValue,
    required this.startDate,
    required this.endDate,
  });
}

class TopSellingProduct {
  final int productId;
  final String productName;
  final String? variantName;
  final double totalQuantity;
  final double totalRevenue;
  final int orderCount;

  TopSellingProduct({
    required this.productId,
    required this.productName,
    required this.variantName,
    required this.totalQuantity,
    required this.totalRevenue,
    required this.orderCount,
  });

  String get displayName {
    if (variantName != null) {
      return '$productName - $variantName';
    }
    return productName;
  }
}

class PaymentMethodBreakdown {
  final String paymentMethod;
  final int orderCount;
  final double totalAmount;

  PaymentMethodBreakdown({
    required this.paymentMethod,
    required this.orderCount,
    required this.totalAmount,
  });
}

class CategorySales {
  final int? categoryId;
  final String categoryName;
  final double totalRevenue;
  final double totalQuantity;
  final int orderCount;

  CategorySales({
    required this.categoryId,
    required this.categoryName,
    required this.totalRevenue,
    required this.totalQuantity,
    required this.orderCount,
  });
}

class DailySales {
  final DateTime date;
  final int orderCount;
  final double totalSales;

  DailySales({
    required this.date,
    required this.orderCount,
    required this.totalSales,
  });
}

class HourlySales {
  final int hour;
  final int orderCount;
  final double totalSales;

  HourlySales({
    required this.hour,
    required this.orderCount,
    required this.totalSales,
  });
}

class CustomerReport {
  final int customerId;
  final String name;
  final String? phone;
  final double totalSpent;
  final int loyaltyPoints;
  final int orderCount;
  final DateTime? lastOrderDate;

  CustomerReport({
    required this.customerId,
    required this.name,
    required this.phone,
    required this.totalSpent,
    required this.loyaltyPoints,
    required this.orderCount,
    required this.lastOrderDate,
  });
}
