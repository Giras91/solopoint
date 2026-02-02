import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../auth_provider.dart';
import '../admin_providers.dart';

class AttendanceLogsScreen extends ConsumerWidget {
  const AttendanceLogsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(userRoleProvider);
    final isAdminOrManager = role == 'admin' || role == 'manager';

    if (!isAdminOrManager) {
      return Scaffold(
        appBar: AppBar(title: const Text('Attendance Logs')),
        body: const Center(child: Text('Admin/Manager access required')),
      );
    }

    final logsAsync = ref.watch(attendanceLogsProvider);
    final usersAsync = ref.watch(allUsersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Attendance Logs')),
      body: usersAsync.when(
        data: (users) {
          final userMap = {for (final u in users) u.id: u};
          return logsAsync.when(
            data: (logs) {
              if (logs.isEmpty) {
                return const Center(child: Text('No attendance logs yet'));
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: logs.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final log = logs[index];
                  final user = userMap[log.userId];
                  final timestamp = DateFormat('MMM dd, HH:mm').format(log.timestamp);
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.access_time),
                      title: Text(_formatAction(log.action)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('User: ${user?.name ?? 'Unknown'}'),
                          Text('Time: $timestamp'),
                          if (log.notes?.isNotEmpty == true) Text('Notes: ${log.notes}'),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text('Error: $error')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
    );
  }

  String _formatAction(String action) {
    switch (action) {
      case 'clock_in':
        return 'Clock In';
      case 'clock_out':
        return 'Clock Out';
      case 'break_start':
        return 'Break Start';
      case 'break_end':
        return 'Break End';
      default:
        return action.replaceAll('_', ' ').toUpperCase();
    }
  }
}
