import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/database.dart';
import '../orders/order_repository.dart';

// Enum for date range selection
enum DateRangeFilter { today, week, month, all }

// State provider for selected date range
final selectedDateRangeProvider = StateProvider<DateRangeFilter>((ref) => DateRangeFilter.today);

// Helper function to get date range
(DateTime, DateTime) _getDateRange(DateRangeFilter filter) {
  final now = DateTime.now();
  switch (filter) {
    case DateRangeFilter.today:
      return (
        DateTime(now.year, now.month, now.day),
        DateTime(now.year, now.month, now.day, 23, 59, 59),
      );
    case DateRangeFilter.week:
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      return (
        DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day),
        DateTime(now.year, now.month, now.day, 23, 59, 59),
      );
    case DateRangeFilter.month:
      return (
        DateTime(now.year, now.month, 1),
        DateTime(now.year, now.month, now.day, 23, 59, 59),
      );
    case DateRangeFilter.all:
      return (
        DateTime(2020, 1, 1), // Far back start date
        DateTime(now.year, now.month, now.day, 23, 59, 59),
      );
  }
}

// Provider for today's sales total
final todaySalesProvider = FutureProvider<double>((ref) async {
  final repo = ref.watch(orderRepositoryProvider);
  final now = DateTime.now();
  final startOfDay = DateTime(now.year, now.month, now.day);
  final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);
  
  return repo.getTotalSales(startOfDay, endOfDay);
});

// Dynamic sales provider based on selected date range
final filteredSalesProvider = FutureProvider<double>((ref) async {
  final repo = ref.watch(orderRepositoryProvider);
  final filter = ref.watch(selectedDateRangeProvider);
  final (start, end) = _getDateRange(filter);
  
  return repo.getTotalSales(start, end);
});

// Provider for recent orders list
final recentOrdersProvider = FutureProvider<List<Order>>((ref) async {
  final repo = ref.watch(orderRepositoryProvider);
  return repo.getRecentOrders(limit: 20);
});

// Provider for payment method breakdown (Today)
final paymentMethodStatsProvider = FutureProvider<Map<String, double>>((ref) async {
  final repo = ref.watch(orderRepositoryProvider);
  final now = DateTime.now();
  final startOfDay = DateTime(now.year, now.month, now.day);
  final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);
  
  return repo.getSalesByPaymentMethod(startOfDay, endOfDay);
});

// Filtered payment method stats based on selected date range
final filteredPaymentMethodStatsProvider = FutureProvider<Map<String, double>>((ref) async {
  final repo = ref.watch(orderRepositoryProvider);
  final filter = ref.watch(selectedDateRangeProvider);
  final (start, end) = _getDateRange(filter);
  
  return repo.getSalesByPaymentMethod(start, end);
});

// Provider for filtered orders list
final filteredOrdersProvider = FutureProvider<List<Order>>((ref) async {
  final repo = ref.watch(orderRepositoryProvider);
  final filter = ref.watch(selectedDateRangeProvider);
  final (start, end) = _getDateRange(filter);
  
  return repo.getOrdersByDateRange(start, end);
});

// Provider for top selling products  
// Note: Uses ProductSalesData from order_repository.dart
final topProductsProvider = FutureProvider((ref) async {
  final repo = ref.watch(orderRepositoryProvider);
  final filter = ref.watch(selectedDateRangeProvider);
  final (start, end) = _getDateRange(filter);
  
  return repo.getTopSellingProducts(start, end, limit: 10);
});

// Provider for category sales breakdown
final categorySalesProvider = FutureProvider<Map<String, double>>((ref) async {
  final repo = ref.watch(orderRepositoryProvider);
  final filter = ref.watch(selectedDateRangeProvider);
  final (start, end) = _getDateRange(filter);
  
  return repo.getSalesByCategory(start, end);
});
