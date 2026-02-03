import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/database.dart';

final analyticsRepositoryProvider = Provider<AnalyticsRepository>((ref) {
  final database = ref.watch(databaseProvider);
  return AnalyticsRepository(database);
});

/// Repository for analytics and reporting data
class AnalyticsRepository {
  final AppDatabase _database;

  AnalyticsRepository(this._database);

  // ============== SALES ANALYTICS ==============

  /// Get sales summary for a date range
  Future<SalesSummary> getSalesSummary(DateTime startDate, DateTime endDate) async {
    final orders = await (_database.select(_database.orders)
          ..where((tbl) =>
              tbl.timestamp.isBiggerOrEqualValue(startDate) &
              tbl.timestamp.isSmallerOrEqualValue(endDate) &
              tbl.status.equals('completed')))
        .get();

    final totalSales = orders.fold<double>(0.0, (sum, order) => sum + order.total);
    final totalOrders = orders.length;
    final totalDiscount = orders.fold<double>(0.0, (sum, order) => sum + order.discount);
    final totalTax = orders.fold<double>(0.0, (sum, order) => sum + order.tax);
    final subtotal = orders.fold<double>(0.0, (sum, order) => sum + order.subtotal);

    return SalesSummary(
      totalSales: totalSales,
      totalOrders: totalOrders,
      totalDiscount: totalDiscount,
      totalTax: totalTax,
      subtotal: subtotal,
      averageOrderValue: totalOrders > 0 ? totalSales / totalOrders : 0.0,
      startDate: startDate,
      endDate: endDate,
    );
  }

  /// Get hourly sales breakdown
  Future<List<HourlySales>> getHourlySales(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final orders = await (_database.select(_database.orders)
          ..where((tbl) =>
              tbl.timestamp.isBiggerOrEqualValue(startOfDay) &
              tbl.timestamp.isSmallerThanValue(endOfDay) &
              tbl.status.equals('completed')))
        .get();

    // Group by hour
    final hourlyData = <int, HourlySales>{};
    for (final order in orders) {
      final hour = order.timestamp.hour;
      if (hourlyData.containsKey(hour)) {
        hourlyData[hour] = HourlySales(
          hour: hour,
          sales: hourlyData[hour]!.sales + order.total,
          orderCount: hourlyData[hour]!.orderCount + 1,
        );
      } else {
        hourlyData[hour] = HourlySales(
          hour: hour,
          sales: order.total,
          orderCount: 1,
        );
      }
    }

    // Fill in missing hours with zero
    final result = <HourlySales>[];
    for (int hour = 0; hour < 24; hour++) {
      result.add(hourlyData[hour] ?? HourlySales(hour: hour, sales: 0.0, orderCount: 0));
    }

    return result;
  }

  /// Get daily sales for a date range
  Future<List<DailySales>> getDailySales(DateTime startDate, DateTime endDate) async {
    final orders = await (_database.select(_database.orders)
          ..where((tbl) =>
              tbl.timestamp.isBiggerOrEqualValue(startDate) &
              tbl.timestamp.isSmallerOrEqualValue(endDate) &
              tbl.status.equals('completed')))
        .get();

    // Group by date
    final dailyData = <String, DailySales>{};
    for (final order in orders) {
      final dateKey = '${order.timestamp.year}-${order.timestamp.month}-${order.timestamp.day}';
      if (dailyData.containsKey(dateKey)) {
        dailyData[dateKey] = DailySales(
          date: DateTime(order.timestamp.year, order.timestamp.month, order.timestamp.day),
          sales: dailyData[dateKey]!.sales + order.total,
          orderCount: dailyData[dateKey]!.orderCount + 1,
        );
      } else {
        dailyData[dateKey] = DailySales(
          date: DateTime(order.timestamp.year, order.timestamp.month, order.timestamp.day),
          sales: order.total,
          orderCount: 1,
        );
      }
    }

    return dailyData.values.toList()..sort((a, b) => a.date.compareTo(b.date));
  }

  /// Get payment method breakdown
  Future<List<PaymentMethodStat>> getPaymentMethodBreakdown(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final orders = await (_database.select(_database.orders)
          ..where((tbl) =>
              tbl.timestamp.isBiggerOrEqualValue(startDate) &
              tbl.timestamp.isSmallerOrEqualValue(endDate) &
              tbl.status.equals('completed')))
        .get();

    final methodData = <String, PaymentMethodStat>{};
    for (final order in orders) {
      final method = order.paymentMethod;
      if (methodData.containsKey(method)) {
        methodData[method] = PaymentMethodStat(
          method: method,
          amount: methodData[method]!.amount + order.total,
          count: methodData[method]!.count + 1,
        );
      } else {
        methodData[method] = PaymentMethodStat(
          method: method,
          amount: order.total,
          count: 1,
        );
      }
    }

    return methodData.values.toList()..sort((a, b) => b.amount.compareTo(a.amount));
  }

  /// Get category sales breakdown
  Future<List<CategorySales>> getCategorySales(DateTime startDate, DateTime endDate) async {
    final query = _database.select(_database.orderItems).join([
      innerJoin(_database.orders, _database.orders.id.equalsExp(_database.orderItems.orderId)),
      innerJoin(_database.products, _database.products.id.equalsExp(_database.orderItems.productId)),
      innerJoin(_database.categories, _database.categories.id.equalsExp(_database.products.categoryId)),
    ])
      ..where(_database.orders.timestamp.isBiggerOrEqualValue(startDate) &
          _database.orders.timestamp.isSmallerOrEqualValue(endDate) &
          _database.orders.status.equals('completed'));

    final results = await query.get();

    final categoryData = <int, CategorySales>{};
    for (final row in results) {
      final category = row.readTable(_database.categories);
      final orderItem = row.readTable(_database.orderItems);

      if (categoryData.containsKey(category.id)) {
        categoryData[category.id] = CategorySales(
          categoryId: category.id,
          categoryName: category.name,
          totalSales: categoryData[category.id]!.totalSales + orderItem.total,
          itemCount: categoryData[category.id]!.itemCount + orderItem.quantity.toInt(),
        );
      } else {
        categoryData[category.id] = CategorySales(
          categoryId: category.id,
          categoryName: category.name,
          totalSales: orderItem.total,
          itemCount: orderItem.quantity.toInt(),
        );
      }
    }

    return categoryData.values.toList()..sort((a, b) => b.totalSales.compareTo(a.totalSales));
  }

  /// Get top selling products
  Future<List<ProductSales>> getTopSellingProducts(
    DateTime startDate,
    DateTime endDate, {
    int limit = 10,
  }) async {
    final query = _database.select(_database.orderItems).join([
      innerJoin(_database.orders, _database.orders.id.equalsExp(_database.orderItems.orderId)),
      innerJoin(_database.products, _database.products.id.equalsExp(_database.orderItems.productId)),
    ])
      ..where(_database.orders.timestamp.isBiggerOrEqualValue(startDate) &
          _database.orders.timestamp.isSmallerOrEqualValue(endDate) &
          _database.orders.status.equals('completed'));

    final results = await query.get();

    final productData = <int, ProductSales>{};
    for (final row in results) {
      final product = row.readTable(_database.products);
      final orderItem = row.readTable(_database.orderItems);

      if (productData.containsKey(product.id)) {
        productData[product.id] = ProductSales(
          productId: product.id,
          productName: orderItem.productName,
          totalSales: productData[product.id]!.totalSales + orderItem.total,
          quantitySold: productData[product.id]!.quantitySold + orderItem.quantity,
          orderCount: productData[product.id]!.orderCount + 1,
        );
      } else {
        productData[product.id] = ProductSales(
          productId: product.id,
          productName: orderItem.productName,
          totalSales: orderItem.total,
          quantitySold: orderItem.quantity,
          orderCount: 1,
        );
      }
    }

    final sorted = productData.values.toList()
      ..sort((a, b) => b.totalSales.compareTo(a.totalSales));
    
    return sorted.take(limit).toList();
  }

  // ============== PROFIT ANALYTICS ==============

  Future<ProfitSummary> getProfitSummary(DateTime startDate, DateTime endDate) async {
    final rows = await _getProfitRows(startDate, endDate);

    final revenue = rows.fold<double>(0.0, (sum, row) => sum + row.revenue);
    final cost = rows.fold<double>(0.0, (sum, row) => sum + row.cost);
    final profit = revenue - cost;

    return ProfitSummary(
      totalRevenue: revenue,
      totalCost: cost,
      totalProfit: profit,
      marginPercent: revenue > 0 ? (profit / revenue) * 100 : 0.0,
      startDate: startDate,
      endDate: endDate,
    );
  }

  Future<List<ProfitTrend>> getProfitTrend(DateTime startDate, DateTime endDate) async {
    final rows = await _getProfitRows(startDate, endDate);

    final trendData = <String, ProfitTrend>{};
    for (final row in rows) {
      final date = row.date;
      final dateKey = '${date.year}-${date.month}-${date.day}';
      if (trendData.containsKey(dateKey)) {
        final current = trendData[dateKey]!;
        trendData[dateKey] = ProfitTrend(
          date: date,
          revenue: current.revenue + row.revenue,
          cost: current.cost + row.cost,
          profit: current.profit + row.profit,
        );
      } else {
        trendData[dateKey] = ProfitTrend(
          date: date,
          revenue: row.revenue,
          cost: row.cost,
          profit: row.profit,
        );
      }
    }

    return trendData.values.toList()..sort((a, b) => a.date.compareTo(b.date));
  }

  Future<List<CategoryProfit>> getProfitByCategory(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final rows = await _getProfitRows(startDate, endDate);

    final categoryData = <int, CategoryProfit>{};
    for (final row in rows) {
      final categoryId = row.categoryId;
      if (categoryData.containsKey(categoryId)) {
        final current = categoryData[categoryId]!;
        final revenue = current.revenue + row.revenue;
        final cost = current.cost + row.cost;
        final profit = revenue - cost;
        categoryData[categoryId] = CategoryProfit(
          categoryId: categoryId,
          categoryName: row.categoryName,
          revenue: revenue,
          cost: cost,
          profit: profit,
          marginPercent: revenue > 0 ? (profit / revenue) * 100 : 0.0,
        );
      } else {
        final revenue = row.revenue;
        final cost = row.cost;
        final profit = revenue - cost;
        categoryData[categoryId] = CategoryProfit(
          categoryId: categoryId,
          categoryName: row.categoryName,
          revenue: revenue,
          cost: cost,
          profit: profit,
          marginPercent: revenue > 0 ? (profit / revenue) * 100 : 0.0,
        );
      }
    }

    return categoryData.values.toList()..sort((a, b) => b.profit.compareTo(a.profit));
  }

  Future<List<ProductProfit>> getTopProfitProducts(
    DateTime startDate,
    DateTime endDate, {
    int limit = 10,
  }) async {
    final rows = await _getProfitRows(startDate, endDate);

    final productData = <int, ProductProfit>{};
    for (final row in rows) {
      final productId = row.productId;
      if (productData.containsKey(productId)) {
        final current = productData[productId]!;
        final revenue = current.revenue + row.revenue;
        final cost = current.cost + row.cost;
        final profit = revenue - cost;
        productData[productId] = ProductProfit(
          productId: productId,
          productName: row.productName,
          revenue: revenue,
          cost: cost,
          profit: profit,
          marginPercent: revenue > 0 ? (profit / revenue) * 100 : 0.0,
          quantitySold: current.quantitySold + row.quantity,
        );
      } else {
        final revenue = row.revenue;
        final cost = row.cost;
        final profit = revenue - cost;
        productData[productId] = ProductProfit(
          productId: productId,
          productName: row.productName,
          revenue: revenue,
          cost: cost,
          profit: profit,
          marginPercent: revenue > 0 ? (profit / revenue) * 100 : 0.0,
          quantitySold: row.quantity,
        );
      }
    }

    final sorted = productData.values.toList()..sort((a, b) => b.profit.compareTo(a.profit));
    return sorted.take(limit).toList();
  }

  Future<List<_ProfitRow>> _getProfitRows(DateTime startDate, DateTime endDate) async {
    final query = _database.select(_database.orderItems).join([
      innerJoin(_database.orders, _database.orders.id.equalsExp(_database.orderItems.orderId)),
      innerJoin(_database.products, _database.products.id.equalsExp(_database.orderItems.productId)),
      leftOuterJoin(
        _database.productVariants,
        _database.productVariants.id.equalsExp(_database.orderItems.variantId),
      ),
      leftOuterJoin(
        _database.categories,
        _database.categories.id.equalsExp(_database.products.categoryId),
      ),
    ])
      ..where(_database.orders.timestamp.isBiggerOrEqualValue(startDate) &
          _database.orders.timestamp.isSmallerOrEqualValue(endDate) &
          _database.orders.status.equals('completed'));

    final results = await query.get();
    final rows = <_ProfitRow>[];

    for (final row in results) {
      final order = row.readTable(_database.orders);
      final item = row.readTable(_database.orderItems);
      final product = row.readTable(_database.products);
      final variant = row.readTableOrNull(_database.productVariants);
      final category = row.readTableOrNull(_database.categories);

      final unitCost = variant?.cost ?? product.cost;
      final cost = unitCost * item.quantity;
      final revenue = item.total;

      rows.add(
        _ProfitRow(
          date: DateTime(order.timestamp.year, order.timestamp.month, order.timestamp.day),
          categoryId: category?.id ?? 0,
          categoryName: category?.name ?? 'Uncategorized',
          productId: product.id,
          productName: item.productName,
          quantity: item.quantity,
          revenue: revenue,
          cost: cost,
        ),
      );
    }

    return rows;
  }

  // ============== X/Z REPORT DATA ==============

  /// Get X-Report data (current shift sales without reset)
  Future<XReportData> getXReport() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    final summary = await getSalesSummary(startOfDay, now);
    final paymentBreakdown = await getPaymentMethodBreakdown(startOfDay, now);
    final categoryBreakdown = await getCategorySales(startOfDay, now);

    return XReportData(
      reportDate: now,
      summary: summary,
      paymentBreakdown: paymentBreakdown,
      categoryBreakdown: categoryBreakdown,
    );
  }

  /// Get Z-Report data (end of day sales)
  Future<ZReportData> getZReport(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final summary = await getSalesSummary(startOfDay, endOfDay);
    final paymentBreakdown = await getPaymentMethodBreakdown(startOfDay, endOfDay);
    final categoryBreakdown = await getCategorySales(startOfDay, endOfDay);
    final topProducts = await getTopSellingProducts(startOfDay, endOfDay, limit: 10);

    return ZReportData(
      reportDate: date,
      summary: summary,
      paymentBreakdown: paymentBreakdown,
      categoryBreakdown: categoryBreakdown,
      topProducts: topProducts,
    );
  }
}

// ============== DATA MODELS ==============

class SalesSummary {
  final double totalSales;
  final int totalOrders;
  final double totalDiscount;
  final double totalTax;
  final double subtotal;
  final double averageOrderValue;
  final DateTime startDate;
  final DateTime endDate;

  SalesSummary({
    required this.totalSales,
    required this.totalOrders,
    required this.totalDiscount,
    required this.totalTax,
    required this.subtotal,
    required this.averageOrderValue,
    required this.startDate,
    required this.endDate,
  });
}

class HourlySales {
  final int hour;
  final double sales;
  final int orderCount;

  HourlySales({
    required this.hour,
    required this.sales,
    required this.orderCount,
  });
}

class DailySales {
  final DateTime date;
  final double sales;
  final int orderCount;

  DailySales({
    required this.date,
    required this.sales,
    required this.orderCount,
  });
}

class PaymentMethodStat {
  final String method;
  final double amount;
  final int count;

  PaymentMethodStat({
    required this.method,
    required this.amount,
    required this.count,
  });
}

class CategorySales {
  final int categoryId;
  final String categoryName;
  final double totalSales;
  final int itemCount;

  CategorySales({
    required this.categoryId,
    required this.categoryName,
    required this.totalSales,
    required this.itemCount,
  });
}

class ProductSales {
  final int productId;
  final String productName;
  final double totalSales;
  final double quantitySold;
  final int orderCount;

  ProductSales({
    required this.productId,
    required this.productName,
    required this.totalSales,
    required this.quantitySold,
    required this.orderCount,
  });
}

class XReportData {
  final DateTime reportDate;
  final SalesSummary summary;
  final List<PaymentMethodStat> paymentBreakdown;
  final List<CategorySales> categoryBreakdown;

  XReportData({
    required this.reportDate,
    required this.summary,
    required this.paymentBreakdown,
    required this.categoryBreakdown,
  });
}

class ZReportData {
  final DateTime reportDate;
  final SalesSummary summary;
  final List<PaymentMethodStat> paymentBreakdown;
  final List<CategorySales> categoryBreakdown;
  final List<ProductSales> topProducts;

  ZReportData({
    required this.reportDate,
    required this.summary,
    required this.paymentBreakdown,
    required this.categoryBreakdown,
    required this.topProducts,
  });
}

class ProfitSummary {
  final double totalRevenue;
  final double totalCost;
  final double totalProfit;
  final double marginPercent;
  final DateTime startDate;
  final DateTime endDate;

  ProfitSummary({
    required this.totalRevenue,
    required this.totalCost,
    required this.totalProfit,
    required this.marginPercent,
    required this.startDate,
    required this.endDate,
  });
}

class ProfitTrend {
  final DateTime date;
  final double revenue;
  final double cost;
  final double profit;

  ProfitTrend({
    required this.date,
    required this.revenue,
    required this.cost,
    required this.profit,
  });
}

class CategoryProfit {
  final int categoryId;
  final String categoryName;
  final double revenue;
  final double cost;
  final double profit;
  final double marginPercent;

  CategoryProfit({
    required this.categoryId,
    required this.categoryName,
    required this.revenue,
    required this.cost,
    required this.profit,
    required this.marginPercent,
  });
}

class ProductProfit {
  final int productId;
  final String productName;
  final double revenue;
  final double cost;
  final double profit;
  final double marginPercent;
  final double quantitySold;

  ProductProfit({
    required this.productId,
    required this.productName,
    required this.revenue,
    required this.cost,
    required this.profit,
    required this.marginPercent,
    required this.quantitySold,
  });
}

class _ProfitRow {
  final DateTime date;
  final int categoryId;
  final String categoryName;
  final int productId;
  final String productName;
  final double quantity;
  final double revenue;
  final double cost;

  _ProfitRow({
    required this.date,
    required this.categoryId,
    required this.categoryName,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.revenue,
    required this.cost,
  });

  double get profit => revenue - cost;
}
