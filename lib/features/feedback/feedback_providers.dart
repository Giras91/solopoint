import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'feedback_repository.dart';

final feedbackDateRangeProvider = StateProvider<DateTimeRange>((ref) {
  final end = DateTime.now();
  final start = end.subtract(const Duration(days: 30));
  return DateTimeRange(start: start, end: end);
});

final feedbackListProvider = StreamProvider((ref) {
  final range = ref.watch(feedbackDateRangeProvider);
  final repository = ref.watch(feedbackRepositoryProvider);
  return repository.watchFeedbacks(range.start, range.end);
});

final feedbackSummaryProvider = FutureProvider((ref) {
  final range = ref.watch(feedbackDateRangeProvider);
  final repository = ref.watch(feedbackRepositoryProvider);
  return repository.getSummary(range.start, range.end);
});
