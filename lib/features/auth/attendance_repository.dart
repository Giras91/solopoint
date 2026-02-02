import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import '../../core/database/database.dart';

final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  final database = ref.watch(databaseProvider);
  return AttendanceRepository(database);
});

class AttendanceRepository {
  final AppDatabase _db;

  AttendanceRepository(this._db);

  /// Watch all attendance logs
  Stream<List<AttendanceLog>> watchAllAttendanceLogs() {
    return (_db.select(_db.attendanceLogs)
          ..orderBy([(a) => OrderingTerm.desc(a.timestamp)]))
        .watch();
  }

  /// Watch attendance logs for a specific user
  Stream<List<AttendanceLog>> watchUserAttendanceLogs(int userId) {
    return (_db.select(_db.attendanceLogs)
          ..where((a) => a.userId.equals(userId))
          ..orderBy([(a) => OrderingTerm.desc(a.timestamp)]))
        .watch();
  }

  /// Watch today's attendance logs
  Stream<List<AttendanceLog>> watchTodayAttendanceLogs() {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

    return (_db.select(_db.attendanceLogs)
          ..where((a) => a.timestamp.isBetweenValues(startOfDay, endOfDay))
          ..orderBy([(a) => OrderingTerm.desc(a.timestamp)]))
        .watch();
  }

  /// Get single attendance log
  Future<AttendanceLog?> getAttendanceLog(int id) {
    return (_db.select(_db.attendanceLogs)..where((a) => a.id.equals(id)))
        .getSingleOrNull();
  }

  /// Clock in user
  Future<int> clockIn(int userId, {String? notes}) {
    return _db.into(_db.attendanceLogs).insert(
      AttendanceLogsCompanion(
        userId: Value(userId),
        action: const Value('clock_in'),
        timestamp: Value(DateTime.now()),
        notes: Value(notes),
      ),
    );
  }

  /// Clock out user
  Future<int> clockOut(int userId, {String? notes}) {
    return _db.into(_db.attendanceLogs).insert(
      AttendanceLogsCompanion(
        userId: Value(userId),
        action: const Value('clock_out'),
        timestamp: Value(DateTime.now()),
        notes: Value(notes),
      ),
    );
  }

  /// Start break
  Future<int> startBreak(int userId, {String? notes}) {
    return _db.into(_db.attendanceLogs).insert(
      AttendanceLogsCompanion(
        userId: Value(userId),
        action: const Value('break_start'),
        timestamp: Value(DateTime.now()),
        notes: Value(notes),
      ),
    );
  }

  /// End break
  Future<int> endBreak(int userId, {String? notes}) {
    return _db.into(_db.attendanceLogs).insert(
      AttendanceLogsCompanion(
        userId: Value(userId),
        action: const Value('break_end'),
        timestamp: Value(DateTime.now()),
        notes: Value(notes),
      ),
    );
  }

  /// Generic log attendance action
  Future<int> logAttendanceAction(
    int userId,
    String action, {
    String? notes,
  }) {
    return _db.into(_db.attendanceLogs).insert(
      AttendanceLogsCompanion(
        userId: Value(userId),
        action: Value(action),
        timestamp: Value(DateTime.now()),
        notes: Value(notes),
      ),
    );
  }

  /// Get current status of user (last action)
  Future<AttendanceLog?> getUserCurrentStatus(int userId) {
    return (_db.select(_db.attendanceLogs)
          ..where((a) => a.userId.equals(userId))
          ..orderBy([(a) => OrderingTerm.desc(a.timestamp)])
          ..limit(1))
        .getSingleOrNull();
  }

  /// Check if user is currently clocked in
  Future<bool> isUserClockedIn(int userId) async {
    final lastStatus = await getUserCurrentStatus(userId);
    if (lastStatus == null) return false;

    final action = lastStatus.action;
    return action == 'clock_in' || action == 'break_end';
  }

  /// Check if user is currently on break
  Future<bool> isUserOnBreak(int userId) async {
    final lastStatus = await getUserCurrentStatus(userId);
    if (lastStatus == null) return false;

    return lastStatus.action == 'break_start';
  }

  /// Get today's clock in time for user
  Future<AttendanceLog?> getTodayClockIn(int userId) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

    return (_db.select(_db.attendanceLogs)
          ..where((a) =>
              a.userId.equals(userId) &
              a.action.equals('clock_in') &
              a.timestamp.isBetweenValues(startOfDay, endOfDay))
          ..orderBy([(a) => OrderingTerm.desc(a.timestamp)])
          ..limit(1))
        .getSingleOrNull();
  }

  /// Calculate hours worked today
  Future<double> calculateTodayHoursWorked(int userId) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

    final logs = await (_db.select(_db.attendanceLogs)
          ..where((a) =>
              a.userId.equals(userId) &
              a.timestamp.isBetweenValues(startOfDay, endOfDay))
          ..orderBy([(a) => OrderingTerm.asc(a.timestamp)]))
        .get();

    double hoursWorked = 0.0;
    DateTime? clockInTime;

    for (final log in logs) {
      if (log.action == 'clock_in' || log.action == 'break_end') {
        clockInTime = log.timestamp;
      } else if (log.action == 'clock_out' || log.action == 'break_start') {
        if (clockInTime != null) {
          hoursWorked +=
              log.timestamp.difference(clockInTime).inMinutes / 60.0;
          clockInTime = null;
        }
      }
    }

    // If still clocked in, calculate up to now
    if (clockInTime != null) {
      hoursWorked += now.difference(clockInTime).inMinutes / 60.0;
    }

    return hoursWorked;
  }

  /// Get all attendance logs for a date range
  Future<List<AttendanceLog>> getAttendanceLogsInRange(
    DateTime startDate,
    DateTime endDate, {
    int? userId,
  }) async {
    var query = _db.select(_db.attendanceLogs)
      ..where((a) => a.timestamp.isBetweenValues(startDate, endDate));

    if (userId != null) {
      query.where((a) => a.userId.equals(userId));
    }

    query.orderBy([(a) => OrderingTerm.desc(a.timestamp)]);

    return query.get();
  }

  /// Delete attendance log
  Future<int> deleteAttendanceLog(int id) {
    return (_db.delete(_db.attendanceLogs)..where((a) => a.id.equals(id)))
        .go();
  }

  /// Update attendance log notes
  Future<int> updateAttendanceLogNotes(int id, String notes) {
    return (_db.update(_db.attendanceLogs)..where((a) => a.id.equals(id)))
        .write(AttendanceLogsCompanion(notes: Value(notes)));
  }
}
