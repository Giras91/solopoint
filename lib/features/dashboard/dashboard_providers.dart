import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../orders/order_repository.dart';
import '../inventory/stock_alert_repository.dart';
import '../tables/table_repository.dart';

// Today's sales summary
final todaysSalesProvider = FutureProvider<DailySalesSummary>((ref) async {
  final orderRepo = ref.watch(orderRepositoryProvider);
  final now = DateTime.now();
  final startOfDay = DateTime(now.year, now.month, now.day);
  final endOfDay = startOfDay.add(const Duration(days: 1));

  final orders = await orderRepo.getOrdersByDateRange(startOfDay, endOfDay);
  final completedOrders = orders.where((o) => o.status == 'completed').toList();

  final totalSales = completedOrders.fold<double>(0, (sum, order) => sum + order.total);
  final orderCount = completedOrders.length;

  return DailySalesSummary(
    totalSales: totalSales,
    orderCount: orderCount,
    date: now,
  );
});

// Low stock items count
final lowStockCountProvider = FutureProvider<int>((ref) async {
  final stockAlertRepo = ref.watch(stockAlertRepositoryProvider);
  final lowStockItems = await stockAlertRepo.getLowStockItems();
  return lowStockItems.length;
});

// Active tables count (occupied tables)
final activeTablesCountProvider = FutureProvider<int>((ref) async {
  final tableRepo = ref.watch(tableRepositoryProvider);
  final tables = await tableRepo.watchAllTables().first;
  
  int activeCount = 0;
  for (final table in tables) {
    if (table.activeOrderId != null) {
      // Check if the order is still active
      final status = await tableRepo.getTableStatus(table.id);
      if (status.isOccupied) {
        activeCount++;
      }
    }
  }
  
  return activeCount;
});

// Combined dashboard stats for easy refresh
final dashboardStatsProvider = FutureProvider<DashboardStats>((ref) async {
  final salesAsync = await ref.watch(todaysSalesProvider.future);
  final lowStockCount = await ref.watch(lowStockCountProvider.future);
  final activeTablesCount = await ref.watch(activeTablesCountProvider.future);

  return DashboardStats(
    todaysSales: salesAsync.totalSales,
    todaysOrders: salesAsync.orderCount,
    lowStockCount: lowStockCount,
    activeTablesCount: activeTablesCount,
  );
});

// Data classes
class DailySalesSummary {
  final double totalSales;
  final int orderCount;
  final DateTime date;

  DailySalesSummary({
    required this.totalSales,
    required this.orderCount,
    required this.date,
  });
}

class DashboardStats {
  final double todaysSales;
  final int todaysOrders;
  final int lowStockCount;
  final int activeTablesCount;

  DashboardStats({
    required this.todaysSales,
    required this.todaysOrders,
    required this.lowStockCount,
    required this.activeTablesCount,
  });
}
