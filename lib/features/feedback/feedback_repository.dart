import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/database.dart';

final feedbackRepositoryProvider = Provider<FeedbackRepository>((ref) {
  final database = ref.watch(databaseProvider);
  return FeedbackRepository(database);
});

class FeedbackRepository {
  final AppDatabase _database;

  FeedbackRepository(this._database);

  Stream<List<CustomerFeedback>> watchFeedbacks(DateTime startDate, DateTime endDate) {
    return (_database.select(_database.customerFeedbacks)
          ..where((tbl) =>
              tbl.createdAt.isBiggerOrEqualValue(startDate) &
              tbl.createdAt.isSmallerOrEqualValue(endDate))
          ..orderBy([(tbl) => OrderingTerm(expression: tbl.createdAt, mode: OrderingMode.desc)]))
        .watch();
  }

  Future<int> addFeedback(CustomerFeedbacksCompanion feedback) {
    return _database.into(_database.customerFeedbacks).insert(feedback);
  }

  Future<FeedbackSummary> getSummary(DateTime startDate, DateTime endDate) async {
    final feedbacks = await (_database.select(_database.customerFeedbacks)
          ..where((tbl) =>
              tbl.createdAt.isBiggerOrEqualValue(startDate) &
              tbl.createdAt.isSmallerOrEqualValue(endDate)))
        .get();

    if (feedbacks.isEmpty) {
      return FeedbackSummary(
        totalCount: 0,
        averageRating: 0.0,
        npsScore: 0.0,
        promoters: 0,
        passives: 0,
        detractors: 0,
      );
    }

    final totalRating = feedbacks.fold<int>(0, (sum, item) => sum + item.rating);
    final averageRating = totalRating / feedbacks.length;

    int promoters = 0;
    int passives = 0;
    int detractors = 0;

    for (final feedback in feedbacks) {
      final score = feedback.npsScore;
      if (score == null) continue;
      if (score >= 9) {
        promoters += 1;
      } else if (score >= 7) {
        passives += 1;
      } else {
        detractors += 1;
      }
    }

    final totalNps = promoters + passives + detractors;
    final npsScore = totalNps == 0
        ? 0.0
        : ((promoters - detractors) / totalNps) * 100;

    return FeedbackSummary(
      totalCount: feedbacks.length,
      averageRating: averageRating,
      npsScore: npsScore,
      promoters: promoters,
      passives: passives,
      detractors: detractors,
    );
  }
}

class FeedbackSummary {
  final int totalCount;
  final double averageRating;
  final double npsScore;
  final int promoters;
  final int passives;
  final int detractors;

  FeedbackSummary({
    required this.totalCount,
    required this.averageRating,
    required this.npsScore,
    required this.promoters,
    required this.passives,
    required this.detractors,
  });
}