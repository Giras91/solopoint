import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/database/database.dart';
import '../feedback_providers.dart';
import '../feedback_repository.dart';

class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({super.key});

  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen> {
  @override
  Widget build(BuildContext context) {
    final range = ref.watch(feedbackDateRangeProvider);
    final feedbackListAsync = ref.watch(feedbackListProvider);
    final feedbackSummaryAsync = ref.watch(feedbackSummaryProvider);
    final formatter = DateFormat('MMM dd, yyyy');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Feedback'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () => _pickDateRange(context, range),
          ),
          IconButton(
            icon: const Icon(Icons.add_comment),
            onPressed: () => _showAddFeedbackDialog(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(feedbackListProvider);
          ref.invalidate(feedbackSummaryProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.date_range),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${formatter.format(range.start)} - ${formatter.format(range.end)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => _pickDateRange(context, range),
                        icon: const Icon(Icons.edit),
                        label: const Text('Change'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              feedbackSummaryAsync.when(
                data: _buildSummaryCards,
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, st) => Text('Error: $err'),
              ),
              const SizedBox(height: 16),
              Text('Feedback Entries', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              feedbackListAsync.when(
                data: _buildFeedbackList,
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, st) => Text('Error: $err'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCards(FeedbackSummary summary) {
    return Row(
      children: [
        Expanded(
          child: _summaryCard(
            'Avg Rating',
            summary.averageRating.toStringAsFixed(2),
            Icons.star,
            Colors.amber,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _summaryCard(
            'NPS',
            summary.npsScore.toStringAsFixed(0),
            Icons.trending_up,
            Colors.green,
            subtitle: 'P:${summary.promoters}  D:${summary.detractors}',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _summaryCard(
            'Responses',
            summary.totalCount.toString(),
            Icons.comment,
            Colors.blue,
          ),
        ),
      ],
    );
  }

  Widget _summaryCard(
    String title,
    String value,
    IconData icon,
    Color color, {
    String? subtitle,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFeedbackList(List<CustomerFeedback> items) {
    if (items.isEmpty) {
      return const Center(child: Text('No feedback yet.'));
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = items[index];
        return ListTile(
          leading: CircleAvatar(
            child: Text(item.rating.toString()),
          ),
          title: Text(item.comment?.isNotEmpty == true ? item.comment! : 'No comment'),
          subtitle: Text('NPS: ${item.npsScore?.toString() ?? "-"}'),
          trailing: Text(
            DateFormat('MMM dd').format(item.createdAt),
            style: const TextStyle(color: Colors.grey),
          ),
        );
      },
    );
  }

  Future<void> _pickDateRange(BuildContext context, DateTimeRange range) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: range,
    );

    if (picked != null) {
      ref.read(feedbackDateRangeProvider.notifier).state = picked;
      ref.invalidate(feedbackListProvider);
      ref.invalidate(feedbackSummaryProvider);
    }
  }

  Future<void> _showAddFeedbackDialog(BuildContext context) async {
    final ratingController = TextEditingController();
    final npsController = TextEditingController();
    final commentController = TextEditingController();

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Add Feedback'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: ratingController,
                  decoration: const InputDecoration(labelText: 'Rating (1-5)'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: npsController,
                  decoration: const InputDecoration(labelText: 'NPS (0-10, optional)'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: commentController,
                  decoration: const InputDecoration(labelText: 'Comment'),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final rating = int.tryParse(ratingController.text) ?? 0;
                final npsScore = int.tryParse(npsController.text);
                final comment = commentController.text.trim();

                if (rating < 1 || rating > 5) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Rating must be between 1 and 5.')),
                  );
                  return;
                }

                await ref.read(feedbackRepositoryProvider).addFeedback(
                      CustomerFeedbacksCompanion.insert(
                        rating: rating,
                        npsScore: drift.Value(npsScore),
                        comment: drift.Value(comment.isEmpty ? null : comment),
                      ),
                    );

                if (mounted) {
                  Navigator.of(dialogContext).pop();
                  ref.invalidate(feedbackListProvider);
                  ref.invalidate(feedbackSummaryProvider);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }
}
