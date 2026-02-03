import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'employee_performance_repository.dart';

final employeePerformanceDateRangeProvider = StateProvider<DateTimeRange>((ref) {
  final end = DateTime.now();
  final start = end.subtract(const Duration(days: 30));
  return DateTimeRange(start: start, end: end);
});

final employeePerformanceProvider = FutureProvider<List<EmployeePerformance>>((ref) {
  final range = ref.watch(employeePerformanceDateRangeProvider);
  final repository = ref.watch(employeePerformanceRepositoryProvider);
  return repository.getPerformance(range.start, range.end);
});
