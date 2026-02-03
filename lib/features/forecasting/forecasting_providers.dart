import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'forecasting_repository.dart';

final forecastDateRangeProvider = StateProvider<DateTimeRange>((ref) {
  final end = DateTime.now();
  final start = end.subtract(const Duration(days: 30));
  return DateTimeRange(start: start, end: end);
});

final leadTimeDaysProvider = StateProvider<int>((ref) => 7);
final safetyStockDaysProvider = StateProvider<int>((ref) => 3);

final forecastItemsProvider = FutureProvider<List<ForecastItem>>((ref) {
  final range = ref.watch(forecastDateRangeProvider);
  final leadTime = ref.watch(leadTimeDaysProvider);
  final safetyStock = ref.watch(safetyStockDaysProvider);

  final repository = ref.watch(forecastingRepositoryProvider);
  return repository.getForecastItems(
    startDate: range.start,
    endDate: range.end,
    leadTimeDays: leadTime,
    safetyStockDays: safetyStock,
  );
});
