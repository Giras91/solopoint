import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/database.dart';
import 'user_repository.dart';
import 'attendance_repository.dart';
import 'audit_journal_repository.dart';
import 'role_repository.dart';

// ======================== User & Role Providers ========================

final allUsersProvider = StreamProvider<List<User>>((ref) {
  return ref.watch(userRepositoryProvider).watchAllUsers();
});

final allRolesProvider = StreamProvider<List<Role>>((ref) {
  return ref.watch(roleRepositoryProvider).watchAllRoles();
});

final activeRolesProvider = StreamProvider<List<Role>>((ref) {
  return ref.watch(roleRepositoryProvider).watchActiveRoles();
});

// ======================== Attendance Providers ========================

final attendanceLogsProvider = StreamProvider<List<AttendanceLog>>((ref) {
  return ref.watch(attendanceRepositoryProvider).watchAllAttendanceLogs();
});

final todayAttendanceProvider = FutureProvider<List<AttendanceLog>>((ref) {
  final now = DateTime.now();
  return ref.watch(attendanceRepositoryProvider).getAttendanceLogsInRange(
    DateTime(now.year, now.month, now.day),
    DateTime(now.year, now.month, now.day).add(const Duration(days: 1)),
  );
});

final userCurrentStatusProvider = FutureProvider.family<AttendanceLog?, int>((ref, userId) {
  return ref.watch(attendanceRepositoryProvider).getUserCurrentStatus(userId);
});

// ======================== Audit Journal Providers ========================

final auditLogsProvider = StreamProvider<List<AuditJournalData>>((ref) {
  return ref.watch(auditJournalRepositoryProvider).watchAllAuditLogs();
});

final todayAuditLogsProvider = FutureProvider<List<AuditJournalData>>((ref) {
  final now = DateTime.now();
  return ref.watch(auditJournalRepositoryProvider).getAuditLogsInRange(
    DateTime(now.year, now.month, now.day),
    DateTime(now.year, now.month, now.day).add(const Duration(days: 1)),
  );
});

final auditSummaryProvider = FutureProvider<AuditSummary>((ref) {
  return ref.watch(auditJournalRepositoryProvider).getAuditSummaryForDate(DateTime.now());
});
