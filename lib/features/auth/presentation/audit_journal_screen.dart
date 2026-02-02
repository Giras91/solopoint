import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../auth_provider.dart';
import '../admin_providers.dart';

class AuditJournalScreen extends ConsumerWidget {
  const AuditJournalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(isAdminProvider);

    if (!isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Audit Journal')),
        body: const Center(child: Text('Admin access required')),
      );
    }

    final logsAsync = ref.watch(auditLogsProvider);
    final usersAsync = ref.watch(allUsersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Audit Journal')),
      body: usersAsync.when(
        data: (users) {
          final userMap = {for (final u in users) u.id: u};
          return logsAsync.when(
            data: (logs) {
              if (logs.isEmpty) {
                return const Center(child: Text('No audit logs yet'));
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: logs.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final log = logs[index];
                  final user = log.userId != null ? userMap[log.userId] : null;
                  final timestamp = DateFormat('MMM dd, HH:mm').format(log.timestamp);
                  final details = _decodeDetails(log.details);

                  return Card(
                    child: ExpansionTile(
                      leading: const Icon(Icons.shield),
                      title: Text(_formatAction(log.action)),
                      subtitle: Text('User: ${user?.name ?? 'System'} • $timestamp'),
                      children: [
                        if (log.entityType != null || log.entityId != null)
                          ListTile(
                            title: const Text('Entity'),
                            subtitle: Text('${log.entityType ?? '-'} #${log.entityId ?? '-'}'),
                          ),
                        if (details != null)
                          ListTile(
                            title: const Text('Details'),
                            subtitle: Text(details),
                          ),
                      ],
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
    return action.replaceAll('_', ' ').toUpperCase();
  }

  String? _decodeDetails(String? details) {
    if (details == null || details.isEmpty) return null;
    try {
      final decoded = jsonDecode(details);
      if (decoded is Map) {
        return decoded.entries.map((e) => '${e.key}: ${e.value}').join('\n');
      }
      return decoded.toString();
    } catch (_) {
      return details;
    }
  }
}
