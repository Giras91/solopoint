import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../services/backup_restore_service.dart';
import '../backup_providers.dart';

class BackupRestoreScreen extends ConsumerStatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  ConsumerState<BackupRestoreScreen> createState() =>
      _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends ConsumerState<BackupRestoreScreen> {
  BackupInfo? _backupInfo;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadBackupInfo();
  }

  Future<void> _loadBackupInfo() async {
    setState(() => _isLoading = true);
    final info = await ref.read(backupRestoreServiceProvider).getBackupInfo();
    setState(() {
      _backupInfo = info;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup & Restore'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Google Drive Backup Section
                  _GoogleDriveBackupSection(),
                  const SizedBox(height: 32),

                  // Database Info Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.storage,
                                  color: Theme.of(context).colorScheme.primary),
                              const SizedBox(width: 12),
                              Text(
                                'Database Information',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          if (_backupInfo != null) ...[
                            _InfoRow(
                              icon: Icons.folder_outlined,
                              label: 'Database Size',
                              value: '${_backupInfo!.databaseSize} MB',
                            ),
                            _InfoRow(
                              icon: Icons.inventory_2_outlined,
                              label: 'Products',
                              value: '${_backupInfo!.productCount}',
                            ),
                            _InfoRow(
                              icon: Icons.receipt_outlined,
                              label: 'Orders',
                              value: '${_backupInfo!.orderCount}',
                            ),
                            _InfoRow(
                              icon: Icons.people_outlined,
                              label: 'Customers',
                              value: '${_backupInfo!.customerCount}',
                            ),
                            _InfoRow(
                              icon: Icons.access_time_outlined,
                              label: 'Last Modified',
                              value: DateFormat('MMM dd, yyyy HH:mm')
                                  .format(_backupInfo!.lastModified),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Backup Section
                  Text(
                    'Backup',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create a copy of your database to protect against data loss',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _createAndShareBackup,
                    icon: const Icon(Icons.backup),
                    label: const Text('Create & Share Backup'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Restore Section
                  Text(
                    'Restore',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Replace your current database with a backup file',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    color: Colors.orange[50],
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              color: Colors.orange[800]),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'This will replace all current data. Make sure to backup first!',
                              style: TextStyle(
                                color: Colors.orange[900],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _restoreFromBackup,
                    icon: const Icon(Icons.restore),
                    label: const Text('Restore from Backup'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                      foregroundColor: Colors.orange,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Best Practices Card
                  Card(
                    color: Colors.blue[50],
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.lightbulb_outlined,
                                  color: Colors.blue[800]),
                              const SizedBox(width: 12),
                              Text(
                                'Best Practices',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[900],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _BestPracticeItem(
                            text: 'Create backups daily or after major changes',
                          ),
                          _BestPracticeItem(
                            text: 'Store backups in multiple locations (USB, cloud)',
                          ),
                          _BestPracticeItem(
                            text: 'Test your backups periodically',
                          ),
                          _BestPracticeItem(
                            text: 'Keep at least 3 recent backups',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Future<void> _createAndShareBackup() async {
    setState(() => _isLoading = true);

    final result = await ref
        .read(backupRestoreServiceProvider)
        .exportAndShareBackup();

    setState(() => _isLoading = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: result.success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<void> _restoreFromBackup() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore Database?'),
        content: const Text(
          'This will replace all current data with the backup file. '
          'Your current database will be saved as a pre-restore backup.\n\n'
          'Are you sure you want to continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    final result =
        await ref.read(backupRestoreServiceProvider).restoreFromBackup();

    setState(() => _isLoading = false);

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: !result.success,
        builder: (context) => AlertDialog(
          title: Text(result.success ? 'Restore Successful' : 'Restore Failed'),
          content: Text(result.message),
          actions: [
            if (result.success)
              ElevatedButton(
                onPressed: () {
                  // Exit the app - user needs to restart
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                child: const Text('OK'),
              )
            else
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
          ],
        ),
      );
    }
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: Colors.grey[700]),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _BestPracticeItem extends StatelessWidget {
  final String text;

  const _BestPracticeItem({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle_outline,
              size: 16, color: Colors.blue[700]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: Colors.blue[900]),
            ),
          ),
        ],
      ),
    );
  }
}

/// Google Drive Backup Section
class _GoogleDriveBackupSection extends ConsumerStatefulWidget {
  const _GoogleDriveBackupSection();

  @override
  ConsumerState<_GoogleDriveBackupSection> createState() =>
      _GoogleDriveBackupSectionState();
}

class _GoogleDriveBackupSectionState
    extends ConsumerState<_GoogleDriveBackupSection> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // ignore: unused_result
      ref.refresh(backupMetadataProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final backupState = ref.watch(backupStateProvider);
    final metadata = ref.watch(backupMetadataProvider);
    final signedIn = ref.watch(googleSignInAccountProvider);

    return Card(
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.cloud_sync, color: Colors.blue[800]),
                const SizedBox(width: 12),
                Text(
                  'Google Drive Cloud Backup',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[900],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Securely backup and restore your database to Google Drive. '
              'Your data is encrypted before upload.',
              style: TextStyle(fontSize: 13, color: Colors.blue[900]),
            ),
            const SizedBox(height: 16),
            signedIn.when(
              data: (account) {
                if (account != null) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green[100],
                          border: Border.all(color: Colors.green),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle, color: Colors.green),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Signed in as: ${account.email}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.green,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Backup metadata
                      metadata.when(
                        data: (backup) {
                          if (backup != null) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(color: Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Latest backup: ${backup.formattedDate}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Size: ${backup.sizeMB} MB',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                        loading: () => const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: LinearProgressIndicator(),
                        ),
                        error: (error, stack) => const SizedBox.shrink(),
                      ),

                      // Action buttons
                      Row(
                        children: [
                          Expanded(
                            child: backupState.isLoading
                                ? ElevatedButton.icon(
                                    onPressed: null,
                                    icon: const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                    label: const Text('Backing Up...'),
                                  )
                                : ElevatedButton.icon(
                                    onPressed: () {
                                      // ignore: unused_result
                                      ref
                                          .read(backupStateProvider.notifier)
                                          .performBackup();
                                    },
                                    icon: const Icon(Icons.cloud_upload),
                                    label: const Text('Backup Now'),
                                  ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: backupState.isLoading
                                ? OutlinedButton.icon(
                                    onPressed: null,
                                    icon: const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                    label: const Text('Restoring...'),
                                  )
                                : OutlinedButton.icon(
                                    onPressed: metadata.hasValue &&
                                            metadata.value != null
                                        ? () {
                                            // ignore: unused_result
                                            _showRestoreConfirmation(context);
                                          }
                                        : null,
                                    icon: const Icon(Icons.cloud_download),
                                    label: const Text('Restore'),
                                  ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () {
                          ref.read(backupStateProvider.notifier).signOut();
                          // ignore: unused_result
                          ref.refresh(googleSignInAccountProvider);
                        },
                        icon: const Icon(Icons.logout),
                        label: const Text('Sign Out'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey,
                        ),
                      ),
                    ],
                  );
                } else {
                  return SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        // ignore: unused_result
                        final success = await ref
                            .read(backupStateProvider.notifier)
                            .signInWithGoogle();
                        if (success && mounted) {
                          // ignore: unused_result
                          ref.refresh(googleSignInAccountProvider);
                          // ignore: unused_result
                          ref.refresh(backupMetadataProvider);
                        }
                      },
                      icon: const Icon(Icons.login),
                      label: const Text('Sign In with Google'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[700],
                      ),
                    ),
                  );
                }
              },
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => Text(
                'Error: $error',
                style: const TextStyle(color: Colors.red),
              ),
            ),

            // Status messages
            if (backupState.hasValue && backupState.value!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green[100],
                    border: Border.all(color: Colors.green),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    backupState.value!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green[800],
                    ),
                  ),
                ),
              ),

            if (backupState.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red[100],
                    border: Border.all(color: Colors.red),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Error: ${backupState.error}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.red[800],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showRestoreConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore from Google Drive?'),
        content: const Text(
          'This will overwrite your current local data with the backup from Google Drive. '
          'This action cannot be undone.\n\n'
          'Are you sure you want to continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(backupStateProvider.notifier).performRestore();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
  }
}
