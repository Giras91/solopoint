import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/database.dart';

final employeePerformanceRepositoryProvider = Provider<EmployeePerformanceRepository>((ref) {
  final database = ref.watch(databaseProvider);
  return EmployeePerformanceRepository(database);
});

class EmployeePerformanceRepository {
  final AppDatabase _database;

  EmployeePerformanceRepository(this._database);

  Future<List<EmployeePerformance>> getPerformance(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final users = await _database.select(_database.users).get();

    final orders = await (_database.select(_database.orders)
          ..where((tbl) =>
              tbl.timestamp.isBiggerOrEqualValue(startDate) &
              tbl.timestamp.isSmallerOrEqualValue(endDate) &
              tbl.status.equals('completed')))
        .get();

    final performanceByUser = <int, _PerformanceAccumulator>{};

    for (final order in orders) {
      final userId = order.userId;
      if (userId == null) continue;

      final accumulator = performanceByUser.putIfAbsent(
        userId,
        () => _PerformanceAccumulator(),
      );

      accumulator.totalSales += order.total;
      accumulator.totalOrders += 1;
      accumulator.totalDiscount += order.discount;
      accumulator.totalTax += order.tax;
    }

    final results = <EmployeePerformance>[];

    for (final user in users) {
      final accumulator = performanceByUser[user.id];
      if (accumulator == null) {
        results.add(
          EmployeePerformance(
            userId: user.id,
            name: user.name,
            role: user.role,
            totalSales: 0,
            totalOrders: 0,
            averageOrderValue: 0,
            totalDiscount: 0,
            totalTax: 0,
          ),
        );
        continue;
      }

      final avgOrderValue = accumulator.totalOrders > 0
          ? accumulator.totalSales / accumulator.totalOrders
          : 0.0;

      results.add(
        EmployeePerformance(
          userId: user.id,
          name: user.name,
          role: user.role,
          totalSales: accumulator.totalSales,
          totalOrders: accumulator.totalOrders,
          averageOrderValue: avgOrderValue,
          totalDiscount: accumulator.totalDiscount,
          totalTax: accumulator.totalTax,
        ),
      );
    }

    results.sort((a, b) => b.totalSales.compareTo(a.totalSales));
    return results;
  }
}

class EmployeePerformance {
  final int userId;
  final String name;
  final String role;
  final double totalSales;
  final int totalOrders;
  final double averageOrderValue;
  final double totalDiscount;
  final double totalTax;

  EmployeePerformance({
    required this.userId,
    required this.name,
    required this.role,
    required this.totalSales,
    required this.totalOrders,
    required this.averageOrderValue,
    required this.totalDiscount,
    required this.totalTax,
  });
}

class _PerformanceAccumulator {
  double totalSales = 0.0;
  int totalOrders = 0;
  double totalDiscount = 0.0;
  double totalTax = 0.0;
}
