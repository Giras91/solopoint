import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import 'dart:convert';
import '../../core/database/database.dart';

final auditJournalRepositoryProvider =
    Provider<AuditJournalRepository>((ref) {
  final database = ref.watch(databaseProvider);
  return AuditJournalRepository(database);
});

class AuditJournalRepository {
  final AppDatabase _db;

  AuditJournalRepository(this._db);

  /// Watch all audit journal entries (newest first)
  Stream<List<AuditJournalData>> watchAllAuditLogs() {
    return (_db.select(_db.auditJournal)
          ..orderBy([(a) => OrderingTerm.desc(a.timestamp)]))
        .watch();
  }

  /// Watch audit logs for a specific user
  Stream<List<AuditJournalData>> watchUserAuditLogs(int userId) {
    return (_db.select(_db.auditJournal)
          ..where((a) => a.userId.equals(userId))
          ..orderBy([(a) => OrderingTerm.desc(a.timestamp)]))
        .watch();
  }

  /// Watch audit logs for a specific action type
  Stream<List<AuditJournalData>> watchAuditLogsByAction(String action) {
    return (_db.select(_db.auditJournal)
          ..where((a) => a.action.equals(action))
          ..orderBy([(a) => OrderingTerm.desc(a.timestamp)]))
        .watch();
  }

  /// Watch today's audit logs
  Stream<List<AuditJournalData>> watchTodayAuditLogs() {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

    return (_db.select(_db.auditJournal)
          ..where((a) => a.timestamp.isBetweenValues(startOfDay, endOfDay))
          ..orderBy([(a) => OrderingTerm.desc(a.timestamp)]))
        .watch();
  }

  /// Get single audit log entry
  Future<AuditJournalData?> getAuditLog(int id) {
    return (_db.select(_db.auditJournal)..where((a) => a.id.equals(id)))
        .getSingleOrNull();
  }

  /// Log void order action (sensitive)
  Future<int> logVoidOrder(
    int? userId,
    int orderId, {
    String? reason,
  }) {
    return _db.into(_db.auditJournal).insert(
      AuditJournalCompanion(
        userId: Value(userId),
        action: const Value('void_order'),
        entityType: const Value('Order'),
        entityId: Value(orderId),
        details: Value(
          jsonEncode({
            'orderId': orderId,
            'reason': reason,
          }),
        ),
        timestamp: Value(DateTime.now()),
      ),
    );
  }

  /// Log open drawer action (sensitive)
  Future<int> logOpenDrawer(
    int? userId, {
    double? amount,
    String? reason,
  }) {
    return _db.into(_db.auditJournal).insert(
      AuditJournalCompanion(
        userId: Value(userId),
        action: const Value('open_drawer'),
        entityType: const Value('Drawer'),
        details: Value(
          jsonEncode({
            'amount': amount,
            'reason': reason,
          }),
        ),
        timestamp: Value(DateTime.now()),
      ),
    );
  }

  /// Log price edit action (sensitive)
  Future<int> logEditPrice(
    int? userId,
    int productId, {
    double? oldPrice,
    double? newPrice,
    String? reason,
  }) {
    return _db.into(_db.auditJournal).insert(
      AuditJournalCompanion(
        userId: Value(userId),
        action: const Value('edit_price'),
        entityType: const Value('Product'),
        entityId: Value(productId),
        details: Value(
          jsonEncode({
            'productId': productId,
            'oldPrice': oldPrice,
            'newPrice': newPrice,
            'reason': reason,
          }),
        ),
        timestamp: Value(DateTime.now()),
      ),
    );
  }

  /// Log user creation (sensitive)
  Future<int> logCreateUser(
    int? userId,
    int newUserId, {
    String? userName,
    String? role,
  }) {
    return _db.into(_db.auditJournal).insert(
      AuditJournalCompanion(
        userId: Value(userId),
        action: const Value('create_user'),
        entityType: const Value('User'),
        entityId: Value(newUserId),
        details: Value(
          jsonEncode({
            'newUserId': newUserId,
            'userName': userName,
            'role': role,
          }),
        ),
        timestamp: Value(DateTime.now()),
      ),
    );
  }

  /// Log user deletion (sensitive)
  Future<int> logDeleteUser(
    int? userId,
    int deletedUserId, {
    String? userName,
  }) {
    return _db.into(_db.auditJournal).insert(
      AuditJournalCompanion(
        userId: Value(userId),
        action: const Value('delete_user'),
        entityType: const Value('User'),
        entityId: Value(deletedUserId),
        details: Value(
          jsonEncode({
            'deletedUserId': deletedUserId,
            'userName': userName,
          }),
        ),
        timestamp: Value(DateTime.now()),
      ),
    );
  }

  /// Log role change (sensitive)
  Future<int> logRoleChange(
    int? userId,
    int affectedUserId, {
    String? oldRole,
    String? newRole,
  }) {
    return _db.into(_db.auditJournal).insert(
      AuditJournalCompanion(
        userId: Value(userId),
        action: const Value('change_role'),
        entityType: const Value('User'),
        entityId: Value(affectedUserId),
        details: Value(
          jsonEncode({
            'affectedUserId': affectedUserId,
            'oldRole': oldRole,
            'newRole': newRole,
          }),
        ),
        timestamp: Value(DateTime.now()),
      ),
    );
  }

  /// Log PIN change (sensitive)
  Future<int> logPinChange(
    int? userId,
    int affectedUserId, {
    String? changedBy,
  }) {
    return _db.into(_db.auditJournal).insert(
      AuditJournalCompanion(
        userId: Value(userId),
        action: const Value('change_pin'),
        entityType: const Value('User'),
        entityId: Value(affectedUserId),
        details: Value(
          jsonEncode({
            'affectedUserId': affectedUserId,
            'changedBy': changedBy,
          }),
        ),
        timestamp: Value(DateTime.now()),
      ),
    );
  }

  /// Log system configuration change (sensitive)
  Future<int> logSystemConfigChange(
    int? userId, {
    String? configKey,
    dynamic oldValue,
    dynamic newValue,
  }) {
    return _db.into(_db.auditJournal).insert(
      AuditJournalCompanion(
        userId: Value(userId),
        action: const Value('system_config_change'),
        entityType: const Value('System'),
        details: Value(
          jsonEncode({
            'configKey': configKey,
            'oldValue': oldValue,
            'newValue': newValue,
          }),
        ),
        timestamp: Value(DateTime.now()),
      ),
    );
  }

  /// Generic audit log entry
  Future<int> logAction(
    String action, {
    int? userId,
    String? entityType,
    int? entityId,
    Map<String, dynamic>? details,
  }) {
    return _db.into(_db.auditJournal).insert(
      AuditJournalCompanion(
        userId: Value(userId),
        action: Value(action),
        entityType: Value(entityType),
        entityId: Value(entityId),
        details: Value(details != null ? jsonEncode(details) : null),
        timestamp: Value(DateTime.now()),
      ),
    );
  }

  /// Get audit logs for a date range
  Future<List<AuditJournalData>> getAuditLogsInRange(
    DateTime startDate,
    DateTime endDate, {
    int? userId,
    String? action,
    String? entityType,
  }) async {
    var query = _db.select(_db.auditJournal)
      ..where((a) => a.timestamp.isBetweenValues(startDate, endDate));

    if (userId != null) {
      query.where((a) => a.userId.equals(userId));
    }

    if (action != null) {
      query.where((a) => a.action.equals(action));
    }

    if (entityType != null) {
      query.where((a) => a.entityType.equals(entityType));
    }

    query.orderBy([(a) => OrderingTerm.desc(a.timestamp)]);

    return query.get();
  }

  /// Get audit summary for sensitive actions on a date
  Future<AuditSummary> getAuditSummaryForDate(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay =
        DateTime(date.year, date.month, date.day, 23, 59, 59);

    final logs = await getAuditLogsInRange(startOfDay, endOfDay);

    int voidOrders = 0;
    int drawerOpens = 0;
    int priceEdits = 0;
    int userChanges = 0;

    for (final log in logs) {
      switch (log.action) {
        case 'void_order':
          voidOrders++;
          break;
        case 'open_drawer':
          drawerOpens++;
          break;
        case 'edit_price':
          priceEdits++;
          break;
        case 'create_user':
        case 'delete_user':
        case 'change_role':
        case 'change_pin':
          userChanges++;
          break;
      }
    }

    return AuditSummary(
      date: date,
      voidOrders: voidOrders,
      drawerOpens: drawerOpens,
      priceEdits: priceEdits,
      userChanges: userChanges,
      totalActions: logs.length,
    );
  }

  /// NOTE: Audit journal is immutable - no update or delete operations
  /// This ensures compliance and audit trail integrity
  /// If an entry needs to be corrected, log a new corrective entry instead
}

/// Summary class for audit metrics
class AuditSummary {
  final DateTime date;
  final int voidOrders;
  final int drawerOpens;
  final int priceEdits;
  final int userChanges;
  final int totalActions;

  AuditSummary({
    required this.date,
    required this.voidOrders,
    required this.drawerOpens,
    required this.priceEdits,
    required this.userChanges,
    required this.totalActions,
  });
}
