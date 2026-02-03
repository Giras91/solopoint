import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../backup_providers.dart';
import '../data/backup_repository.dart';

class BackupSettingsScreen extends ConsumerWidget {
  const BackupSettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final backupSummary = ref.watch(backupSummaryProvider);
    final backupHistory = ref.watch(backupHistoryProvider);
    final isCreatingBackup = ref.watch(backupCreatingProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cloud Backup & Sync'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Backup Summary Cards
            backupSummary.when(
              data: (summary) => Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Backup Summary',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _SummaryCard(
                            title: 'Total Backups',
                            value: summary.totalBackups.toString(),
                            icon: Icons.backup,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _SummaryCard(
                            title: 'Latest Size',
                            value: '${(summary.latestBackupSize / 1024).toStringAsFixed(2)} KB',
                            icon: Icons.storage,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Last Backup',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                          const SizedBox(height: 4),
                          if (summary.lastBackupTime != null)
                            Text(
                              DateFormat('MMM dd, yyyy - HH:mm').format(summary.lastBackupTime!),
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            )
                          else
                            Text(
                              'No backups created yet',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          const SizedBox(height: 4),
                          Text(
                            summary.lastBackupStatus ?? 'N/A',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: (summary.lastBackupStatus?.contains('Successfully') ?? false)
                                      ? Colors.green
                                      : Colors.orange,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              loading: () => const Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              ),
              error: (err, st) => Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Error loading summary: $err'),
              ),
            ),

            const Divider(),

            // Backup Controls
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Backup Controls',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: isCreatingBackup
                          ? null
                          : () => _createBackup(context, ref),
                      icon: isCreatingBackup
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.cloud_upload),
                      label: Text(isCreatingBackup ? 'Creating Backup...' : 'Create Backup Now'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Consumer(
                    builder: (context, ref, child) {
                      final autoBackup = ref.watch(autoBackupEnabledProvider);
                      return CheckboxListTile(
                        title: const Text('Enable Auto Backup'),
                        subtitle: const Text('Automatically backup daily'),
                        value: autoBackup,
                        onChanged: (val) {
                          ref.read(autoBackupEnabledProvider.notifier).state = val ?? false;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(val == true ? 'Auto backup enabled' : 'Auto backup disabled'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),

            const Divider(),

            // Backup History
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Backup History',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  backupHistory.when(
                    data: (backups) {
                      if (backups.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 32.0),
                            child: Text(
                              'No backups found',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.grey,
                                  ),
                            ),
                          ),
                        );
                      }

                      return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: backups.length,
                        separatorBuilder: (_, __) => const Divider(),
                        itemBuilder: (context, index) {
                          final backup = backups[index];
                          return ListTile(
                            leading: Icon(
                              Icons.folder_zip,
                              color: Colors.blue.shade600,
                            ),
                            title: Text(backup.filename),
                            subtitle: Text(
                              DateFormat('MMM dd, yyyy - HH:mm').format(backup.createdAt),
                            ),
                            trailing: SizedBox(
                              width: 120,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Text(
                                    '${(backup.fileSize / 1024).toStringAsFixed(2)} KB',
                                    style: Theme.of(context).textTheme.labelSmall,
                                  ),
                                  PopupMenuButton<String>(
                                    onSelected: (value) {
                                      if (value == 'restore') {
                                        _restoreBackup(context, ref, backup.id);
                                      } else if (value == 'delete') {
                                        _deleteBackup(context, ref, backup.id);
                                      }
                                    },
                                    itemBuilder: (BuildContext context) => [
                                      const PopupMenuItem(
                                        value: 'restore',
                                        child: Row(
                                          children: [
                                            Icon(Icons.restore, size: 20),
                                            SizedBox(width: 8),
                                            Text('Restore'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(Icons.delete, size: 20, color: Colors.red),
                                            SizedBox(width: 8),
                                            Text('Delete'),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (err, st) => Center(
                      child: Text('Error loading backups: $err'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _createBackup(BuildContext context, WidgetRef ref) async {
    ref.read(backupCreatingProvider.notifier).state = true;
    ref.read(backupStatusProvider.notifier).state = 'Creating backup...';

    try {
      final repository = ref.read(backupRepositoryProvider);
      await repository.createAndUploadBackup();

      ref.read(backupStatusProvider.notifier).state = 'Backup completed successfully';
      ref.read(lastSyncTimeProvider.notifier).state = DateTime.now();

      // Refresh backup history
      ref.invalidate(backupHistoryProvider);
      ref.invalidate(backupSummaryProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Backup created successfully'),
            duration: Duration(seconds: 3),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ref.read(backupStatusProvider.notifier).state = 'Backup failed: $e';

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backup failed: $e'),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      ref.read(backupCreatingProvider.notifier).state = false;
    }
  }

  void _restoreBackup(BuildContext context, WidgetRef ref, String backupId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore Backup?'),
        content: const Text(
          'This will replace your current database with the backup. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    ref.read(backupRestoringProvider.notifier).state = true;
    ref.read(backupStatusProvider.notifier).state = 'Restoring backup...';

    try {
      final repository = ref.read(backupRepositoryProvider);
      await repository.restoreBackup(backupId);

      ref.read(backupStatusProvider.notifier).state = 'Backup restored successfully';

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Backup restored successfully. Please restart the app.'),
            duration: Duration(seconds: 3),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ref.read(backupStatusProvider.notifier).state = 'Restore failed: $e';

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Restore failed: $e'),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      ref.read(backupRestoringProvider.notifier).state = false;
    }
  }

  void _deleteBackup(BuildContext context, WidgetRef ref, String backupId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Backup?'),
        content: const Text('This backup will be permanently deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final repository = ref.read(backupRepositoryProvider);
      await repository.deleteBackup(backupId);

      // Refresh backup history
      ref.invalidate(backupHistoryProvider);
      ref.invalidate(backupSummaryProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Backup deleted successfully'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete backup: $e'),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.blue.shade600, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade600,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}
