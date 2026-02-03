import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import '../../../core/database/database.dart';

extension FirstWhereOrNull<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    try {
      return firstWhere(test);
    } catch (e) {
      return null;
    }
  }
}

class ReportsExportService {
  /// Export attendance logs to CSV format
  static String exportAttendanceToCSV(
    List<AttendanceLog> logs,
    List<User> users,
  ) {
    final List<List<dynamic>> csvData = [
      ['User', 'Action', 'Timestamp', 'Notes'],
    ];

    for (final log in logs) {
      final user = users.firstWhereOrNull(
        (u) => u.id == log.userId,
      );

      csvData.add([
        user?.name ?? 'Unknown',
        log.action,
        _formatDateTime(log.timestamp),
        log.notes ?? '',
      ]);
    }

    return const ListToCsvConverter().convert(csvData);
  }

  /// Export audit logs to CSV format
  static String exportAuditToCSV(
    List<AuditJournalData> logs,
    List<User> users,
  ) {
    final List<List<dynamic>> csvData = [
      ['User', 'Action', 'Entity Type', 'Entity ID', 'Timestamp', 'Details'],
    ];

    for (final log in logs) {
      final user = users.firstWhereOrNull(
        (u) => u.id == log.userId,
      );

      csvData.add([
        user?.name ?? 'Unknown',
        log.action,
        log.entityType,
        log.entityId?.toString() ?? 'N/A',
        _formatDateTime(log.timestamp),
        log.details ?? '',
      ]);
    }

    return const ListToCsvConverter().convert(csvData);
  }

  /// Export attendance summary (hours worked per person)
  static String exportAttendanceSummaryToCSV(
    Map<int, AttendanceSummary> summary,
    List<User> users,
  ) {
    final List<List<dynamic>> csvData = [
      ['User', 'Total Hours', 'Break Hours', 'Clock Ins', 'Notes'],
    ];

    for (final entry in summary.entries) {
      final user = users.firstWhereOrNull(
        (u) => u.id == entry.key,
      );

      csvData.add([
        user?.name ?? 'Unknown',
        '${entry.value.totalHours.toStringAsFixed(2)} hrs',
        '${entry.value.breakHours.toStringAsFixed(2)} hrs',
        entry.value.clockIns,
        entry.value.notes ?? '',
      ]);
    }

    return const ListToCsvConverter().convert(csvData);
  }

  static String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return 'N/A';
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(dateTime);
  }
}

/// Represents a summary of attendance for a user
class AttendanceSummary {
  final double totalHours;
  final double breakHours;
  final int clockIns;
  final String? notes;

  AttendanceSummary({
    required this.totalHours,
    required this.breakHours,
    required this.clockIns,
    this.notes,
  });
}
