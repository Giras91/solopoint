import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/database.dart';

final forecastingRepositoryProvider = Provider<ForecastingRepository>((ref) {
  final database = ref.watch(databaseProvider);
  return ForecastingRepository(database);
});

class ForecastingRepository {
  final AppDatabase _database;

  ForecastingRepository(this._database);

  Future<List<ForecastItem>> getForecastItems({
    required DateTime startDate,
    required DateTime endDate,
    required int leadTimeDays,
    required int safetyStockDays,
  }) async {
    final normalizedStart = DateTime(startDate.year, startDate.month, startDate.day);
    final normalizedEnd = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
    final dayCount = normalizedEnd.difference(normalizedStart).inDays + 1;
    final forecastDays = leadTimeDays + safetyStockDays;

    final products = await _database.select(_database.products).get();

    final orderItems = await (_database.select(_database.orderItems).join([
          innerJoin(
            _database.orders,
            _database.orders.id.equalsExp(_database.orderItems.orderId),
          ),
        ])
          ..where(_database.orders.timestamp.isBiggerOrEqualValue(normalizedStart) &
              _database.orders.timestamp.isSmallerOrEqualValue(normalizedEnd) &
              _database.orders.status.equals('completed')))
        .get();

    final quantityByProduct = <int, double>{};
    final revenueByProduct = <int, double>{};

    for (final row in orderItems) {
      final item = row.readTable(_database.orderItems);
      quantityByProduct.update(item.productId, (value) => value + item.quantity,
          ifAbsent: () => item.quantity);
      revenueByProduct.update(item.productId, (value) => value + item.total,
          ifAbsent: () => item.total);
    }

    final results = <ForecastItem>[];
    for (final product in products) {
      final totalSold = quantityByProduct[product.id] ?? 0.0;
      final totalRevenue = revenueByProduct[product.id] ?? 0.0;
      final avgDailySales = dayCount > 0 ? totalSold / dayCount : 0.0;
      final forecastDemand = avgDailySales * forecastDays;
      final suggestedReorder = forecastDemand - product.stockQuantity;
      final daysCoverage = avgDailySales > 0 ? product.stockQuantity / avgDailySales : double.infinity;

      results.add(
        ForecastItem(
          productId: product.id,
          productName: product.name,
          currentStock: product.stockQuantity,
          totalSold: totalSold,
          totalRevenue: totalRevenue,
          avgDailySales: avgDailySales,
          forecastDays: forecastDays,
          forecastDemand: forecastDemand,
          suggestedReorder: suggestedReorder > 0 ? suggestedReorder : 0.0,
          daysCoverage: daysCoverage,
          status: _getStatus(
            currentStock: product.stockQuantity,
            daysCoverage: daysCoverage,
            leadTimeDays: leadTimeDays,
            forecastDays: forecastDays,
          ),
        ),
      );
    }

    results.sort((a, b) => b.suggestedReorder.compareTo(a.suggestedReorder));
    return results;
  }

  ForecastStatus _getStatus({
    required double currentStock,
    required double daysCoverage,
    required int leadTimeDays,
    required int forecastDays,
  }) {
    if (currentStock <= 0) return ForecastStatus.outOfStock;
    if (daysCoverage.isInfinite) return ForecastStatus.ok;
    if (daysCoverage < leadTimeDays) return ForecastStatus.urgent;
    if (daysCoverage < forecastDays) return ForecastStatus.low;
    return ForecastStatus.ok;
  }
}

class ForecastItem {
  final int productId;
  final String productName;
  final double currentStock;
  final double totalSold;
  final double totalRevenue;
  final double avgDailySales;
  final int forecastDays;
  final double forecastDemand;
  final double suggestedReorder;
  final double daysCoverage;
  final ForecastStatus status;

  ForecastItem({
    required this.productId,
    required this.productName,
    required this.currentStock,
    required this.totalSold,
    required this.totalRevenue,
    required this.avgDailySales,
    required this.forecastDays,
    required this.forecastDemand,
    required this.suggestedReorder,
    required this.daysCoverage,
    required this.status,
  });
}

enum ForecastStatus { ok, low, urgent, outOfStock }
