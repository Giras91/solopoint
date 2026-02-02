import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/database.dart';
import 'user_repository.dart';
import 'attendance_repository.dart';
import 'audit_journal_repository.dart';

final allUsersProvider = StreamProvider<List<User>>((ref) {
  return ref.watch(userRepositoryProvider).watchAllUsers();
});

final attendanceLogsProvider = StreamProvider<List<AttendanceLog>>((ref) {
  return ref.watch(attendanceRepositoryProvider).watchAllAttendanceLogs();
});

final auditLogsProvider = StreamProvider<List<AuditJournalData>>((ref) {
  return ref.watch(auditJournalRepositoryProvider).watchAllAuditLogs();
});
