import 'package:flutter/material.dart';

/// Utility class for handling date range selection
class DateRangeFilter {
  final DateTime startDate;
  final DateTime endDate;

  DateRangeFilter({
    required this.startDate,
    required this.endDate,
  });

  /// Get today's date range (start of day to end of day)
  static DateRangeFilter today() {
    final now = DateTime.now();
    return DateRangeFilter(
      startDate: DateTime(now.year, now.month, now.day),
      endDate: DateTime(now.year, now.month, now.day, 23, 59, 59),
    );
  }

  /// Get yesterday's date range
  static DateRangeFilter yesterday() {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    return DateRangeFilter(
      startDate: DateTime(yesterday.year, yesterday.month, yesterday.day),
      endDate: DateTime(yesterday.year, yesterday.month, yesterday.day, 23, 59, 59),
    );
  }

  /// Get this week's date range (Monday to Sunday)
  static DateRangeFilter thisWeek() {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final sunday = monday.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
    return DateRangeFilter(
      startDate: DateTime(monday.year, monday.month, monday.day),
      endDate: sunday,
    );
  }

  /// Get this month's date range
  static DateRangeFilter thisMonth() {
    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month, 1);
    final lastDay = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    return DateRangeFilter(
      startDate: firstDay,
      endDate: lastDay,
    );
  }

  /// Get last 30 days
  static DateRangeFilter last30Days() {
    final now = DateTime.now();
    return DateRangeFilter(
      startDate: now.subtract(const Duration(days: 30)),
      endDate: DateTime(now.year, now.month, now.day, 23, 59, 59),
    );
  }

  /// Check if a date falls within this range
  bool contains(DateTime date) {
    return date.isAfter(startDate) && date.isBefore(endDate);
  }

  /// Format range as string
  String get displayText {
    final start = _formatDate(startDate);
    final end = _formatDate(endDate);
    if (start == end) {
      return start;
    }
    return '$start to $end';
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

/// Dialog for selecting date range
class DateRangePickerDialog extends StatefulWidget {
  final DateRangeFilter initialRange;
  final Function(DateRangeFilter) onConfirm;

  const DateRangePickerDialog({
    required this.initialRange,
    required this.onConfirm,
    super.key,
  });

  @override
  State<DateRangePickerDialog> createState() => _DateRangePickerDialogState();
}

class _DateRangePickerDialogState extends State<DateRangePickerDialog> {
  late DateTime _startDate;
  late DateTime _endDate;
  String? _selectedPreset;

  @override
  void initState() {
    super.initState();
    _startDate = widget.initialRange.startDate;
    _endDate = widget.initialRange.endDate;
  }

  void _applyPreset(String preset) {
    final range = switch (preset) {
      'today' => DateRangeFilter.today(),
      'yesterday' => DateRangeFilter.yesterday(),
      'thisWeek' => DateRangeFilter.thisWeek(),
      'thisMonth' => DateRangeFilter.thisMonth(),
      'last30Days' => DateRangeFilter.last30Days(),
      _ => null,
    };

    if (range != null) {
      setState(() {
        _selectedPreset = preset;
        _startDate = range.startDate;
        _endDate = range.endDate;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Date Range'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Preset buttons
            Text(
              'Quick Select',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _buildPresetButton('Today', 'today'),
                _buildPresetButton('Yesterday', 'yesterday'),
                _buildPresetButton('This Week', 'thisWeek'),
                _buildPresetButton('This Month', 'thisMonth'),
                _buildPresetButton('Last 30 Days', 'last30Days'),
              ],
            ),
            const SizedBox(height: 24),

            // Custom date range
            Text(
              'Custom Range',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 12),

            // Start date
            ListTile(
              title: const Text('Start Date'),
              subtitle: Text(_formatDate(_startDate)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () => _selectStartDate(context),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            const SizedBox(height: 12),

            // End date
            ListTile(
              title: const Text('End Date'),
              subtitle: Text(_formatDate(_endDate)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () => _selectEndDate(context),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: Colors.grey[300]!),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onConfirm(
              DateRangeFilter(
                startDate: _startDate,
                endDate: _endDate,
              ),
            );
            Navigator.pop(context);
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }

  Widget _buildPresetButton(String label, String preset) {
    final isSelected = _selectedPreset == preset;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => _applyPreset(preset),
    );
  }

  Future<void> _selectStartDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: _endDate,
    );

    if (picked != null) {
      setState(() {
        _startDate = picked;
        _selectedPreset = null;
      });
    }
  }

  Future<void> _selectEndDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        _endDate = picked;
        _selectedPreset = null;
      });
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
