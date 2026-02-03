import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/admin_providers.dart';
import '../auth/auth_provider.dart';
import 'staff_detail_dialog.dart';
import 'audit_log_detail_dialog.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ignore: unused_local_variable
    final currentUser = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        elevation: 0,
      ),
      body: DefaultTabController(
        length: 4,
        child: Column(
          children: [
            TabBar(
              tabs: const [
                Tab(
                  icon: Icon(Icons.people),
                  text: 'Staff',
                ),
                Tab(
                  icon: Icon(Icons.schedule),
                  text: 'Attendance',
                ),
                Tab(
                  icon: Icon(Icons.history),
                  text: 'Audit Logs',
                ),
                Tab(
                  icon: Icon(Icons.assessment),
                  text: 'Summary',
                ),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  const _StaffManagementTab(),
                  const _AttendanceTab(),
                  const _AuditLogsTab(),
                  const _SummaryTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Staff Management Tab
class _StaffManagementTab extends ConsumerWidget {
  const _StaffManagementTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(allUsersProvider);
    final rolesAsync = ref.watch(allRolesProvider);

    return usersAsync.when(
      data: (users) => rolesAsync.when(
        data: (roles) => _buildStaffList(context, users, roles),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(child: Text('Error: $err')),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, st) => Center(child: Text('Error: $err')),
    );
  }

  Widget _buildStaffList(BuildContext context, List users, List roles) {
    if (users.isEmpty) {
      return const Center(
        child: Text('No staff members found'),
      );
    }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            final roleDisplay = user.role ?? 'N/A';

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: user.isActive ? Colors.green : Colors.grey,
                  child: Text(
                    user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                title: Text(user.name),
                subtitle: Text('Role: $roleDisplay'),
                trailing: Icon(
                  user.isActive ? Icons.check_circle : Icons.cancel,
                  color: user.isActive ? Colors.green : Colors.red,
                ),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => StaffDetailDialog(user: user),
                  );
                },
              ),
            );
          },
        );
  }
}

/// Attendance Tracking Tab
class _AttendanceTab extends ConsumerWidget {
  const _AttendanceTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attendanceAsync = ref.watch(todayAttendanceProvider);
    final usersAsync = ref.watch(allUsersProvider);

    return attendanceAsync.when(
      data: (logs) => usersAsync.when(
        data: (users) => _buildAttendanceView(context, logs, users),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(child: Text('Error: $err')),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, st) => Center(child: Text('Error: $err')),
    );
  }

  Widget _buildAttendanceView(
    BuildContext context,
    List logs,
    List users,
  ) {
    if (logs.isEmpty) {
      return const Center(
        child: Text('No attendance records for today'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: logs.length,
      itemBuilder: (context, index) {
        final log = logs[index];
        final user = users.cast().firstWhere(
          (u) => u.id == log.userId,
          orElse: () => null,
        );

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: Icon(
              _getActionIcon(log.action),
              color: _getActionColor(log.action),
            ),
            title: Text(user?.name ?? 'Unknown'),
            subtitle: Text('${log.action} at ${log.timestamp}'),
            trailing: Text(
              '${log.timestamp.hour.toString().padLeft(2, '0')}:${log.timestamp.minute.toString().padLeft(2, '0')}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        );
      },
    );
  }

  IconData _getActionIcon(String action) {
    switch (action) {
      case 'clock_in':
        return Icons.login;
      case 'clock_out':
        return Icons.logout;
      case 'break_start':
        return Icons.pause;
      case 'break_end':
        return Icons.play_arrow;
      default:
        return Icons.info;
    }
  }

  Color _getActionColor(String action) {
    switch (action) {
      case 'clock_in':
        return Colors.green;
      case 'clock_out':
        return Colors.red;
      case 'break_start':
        return Colors.orange;
      case 'break_end':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}

/// Audit Logs Tab
class _AuditLogsTab extends ConsumerWidget {
  const _AuditLogsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auditAsync = ref.watch(todayAuditLogsProvider);
    final usersAsync = ref.watch(allUsersProvider);

    return auditAsync.when(
      data: (logs) => usersAsync.when(
        data: (users) => _buildAuditView(context, logs, users),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(child: Text('Error: $err')),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, st) => Center(child: Text('Error: $err')),
    );
  }

  Widget _buildAuditView(
    BuildContext context,
    List logs,
    List users,
  ) {
    if (logs.isEmpty) {
      return const Center(
        child: Text('No audit logs for today'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: logs.length,
      itemBuilder: (context, index) {
        final log = logs[index];
        final user = users.cast().firstWhere(
          (u) => u.id == log.userId,
          orElse: () => null,
        );

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: Icon(
              _getAuditIcon(log.action),
              color: Colors.deepOrange,
            ),
            title: Text(log.action),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('User: ${user?.name ?? "Unknown"}'),
                Text('Entity: ${log.entityType}'),
                if (log.timestamp != null)
                  Text(
                    '${log.timestamp.hour.toString().padLeft(2, '0')}:'
                    '${log.timestamp.minute.toString().padLeft(2, '0')}',
                  ),
              ],
            ),
            isThreeLine: true,
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AuditLogDetailDialog(
                  log: log,
                  user: user,
                ),
              );
            },
          ),
        );
      },
    );
  }

  IconData _getAuditIcon(String action) {
    if (action.contains('void')) return Icons.cancel;
    if (action.contains('drawer')) return Icons.lock_open;
    if (action.contains('price')) return Icons.local_atm;
    if (action.contains('user')) return Icons.person;
    if (action.contains('pin')) return Icons.security;
    if (action.contains('config')) return Icons.settings;
    return Icons.info;
  }
}

/// Summary Tab - Shows high-level stats
class _SummaryTab extends ConsumerWidget {
  const _SummaryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(allUsersProvider);
    final attendanceAsync = ref.watch(todayAttendanceProvider);
    final auditSummaryAsync = ref.watch(auditSummaryProvider);

    return usersAsync.when(
      data: (users) => attendanceAsync.when(
        data: (attendance) => auditSummaryAsync.when(
          data: (auditSummary) => _buildSummary(
            context,
            users,
            attendance,
            auditSummary,
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, st) => Center(child: Text('Error: $err')),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(child: Text('Error: $err')),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, st) => Center(child: Text('Error: $err')),
    );
  }

  Widget _buildSummary(
    BuildContext context,
    List users,
    List attendance,
    dynamic auditSummary,
  ) {
    // ignore: unused_local_variable
    final colorScheme = Theme.of(context).colorScheme;

    // Count clocked in users
    final clockedInCount = attendance
        .where((log) => log.action == 'clock_in')
        .length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Stats cards
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  context,
                  'Total Staff',
                  users.length.toString(),
                  Icons.people,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  context,
                  'Clocked In',
                  clockedInCount.toString(),
                  Icons.login,
                  Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  context,
                  'Today Actions',
                  attendance.length.toString(),
                  Icons.schedule,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  context,
                  'Audit Events',
                  auditSummary?.totalEvents?.toString() ?? '0',
                  Icons.history,
                  Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Audit summary section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Audit Summary',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  if (auditSummary != null)
                    Column(
                      children: [
                        _buildSummaryRow('Voids', auditSummary.voidCount ?? 0),
                        _buildSummaryRow('Drawer Opens', auditSummary.drawerOpens ?? 0),
                        _buildSummaryRow('Price Edits', auditSummary.priceEdits ?? 0),
                        _buildSummaryRow('User Changes', auditSummary.userChanges ?? 0),
                        _buildSummaryRow('Pin Changes', auditSummary.pinChanges ?? 0),
                        _buildSummaryRow('Config Changes', auditSummary.configChanges ?? 0),
                      ],
                    )
                  else
                    const Center(
                      child: Text('No audit data available'),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 12),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              count.toString(),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
