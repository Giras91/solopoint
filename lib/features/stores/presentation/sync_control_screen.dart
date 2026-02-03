import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database.dart';
import '../store_providers.dart';
import '../../sync/vpn_sync_service.dart';

class SyncControlScreen extends ConsumerStatefulWidget {
  const SyncControlScreen({super.key});

  @override
  ConsumerState<SyncControlScreen> createState() => _SyncControlScreenState();
}

class _SyncControlScreenState extends ConsumerState<SyncControlScreen> {
  bool _isServerRunning = false;
  bool _isSyncing = false;
  String? _lastSyncMessage;
  DateTime? _lastSyncTime;

  @override
  Widget build(BuildContext context) {
    final mainTerminalAsync = ref.watch(mainTerminalProvider);
    final currentStore = ref.watch(currentStoreProvider);
    final syncLogsAsync = ref.watch(syncLogsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sync Control'),
      ),
      body: Column(
        children: [
          _buildStoreInfo(currentStore),
          const Divider(),
          mainTerminalAsync.when(
            data: (mainTerminal) {
              if (mainTerminal != null && currentStore?.isMainTerminal == true) {
                return _buildServerControls();
              } else {
                return _buildClientControls(currentStore);
              }
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Error: $err')),
          ),
          const Divider(),
          Expanded(
            child: _buildSyncLogs(syncLogsAsync),
          ),
        ],
      ),
    );
  }

  Widget _buildStoreInfo(Store? store) {
    if (store == null) {
      return Card(
        margin: const EdgeInsets.all(16),
        color: Colors.orange.shade50,
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.warning, color: Colors.orange),
              SizedBox(width: 12),
              Text('No store selected'),
            ],
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.all(16),
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  store.isMainTerminal ? Icons.dns : Icons.store,
                  color: Colors.blue,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        store.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        store.isMainTerminal ? 'Main Terminal (Server)' : 'Branch Outlet (Client)',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (store.lastSyncAt != null) ...[
              const SizedBox(height: 8),
              Text(
                'Last Sync: ${_formatDateTime(store.lastSyncAt!)}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildServerControls() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Server Controls',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Server Status: ${_isServerRunning ? "Running" : "Stopped"}',
                        style: TextStyle(
                          color: _isServerRunning ? Colors.green : Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Port: 8888',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _toggleServer,
                  icon: Icon(_isServerRunning ? Icons.stop : Icons.play_arrow),
                  label: Text(_isServerRunning ? 'Stop Server' : 'Start Server'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isServerRunning ? Colors.red : Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            if (_lastSyncMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_lastSyncMessage!),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildClientControls(Store? store) {
    if (store == null) return const SizedBox.shrink();

    final pendingChangesAsync = ref.watch(pendingChangesProvider(store.id));

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Client Controls',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            pendingChangesAsync.when(
              data: (changes) => Text(
                'Pending Changes: ${changes.length}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              loading: () => const Text('Loading...'),
              error: (_, __) => const Text('Error loading changes'),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isSyncing ? null : () => _performSync(store, 'pull'),
                    icon: const Icon(Icons.download),
                    label: const Text('Pull Updates'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isSyncing ? null : () => _performSync(store, 'push'),
                    icon: const Icon(Icons.upload),
                    label: const Text('Push Changes'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSyncing ? null : () => _performSync(store, 'full'),
                icon: _isSyncing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync),
                label: Text(_isSyncing ? 'Syncing...' : 'Full Sync'),
              ),
            ),
            if (_lastSyncMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_lastSyncMessage!),
                    if (_lastSyncTime != null)
                      Text(
                        _formatDateTime(_lastSyncTime!),
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSyncLogs(AsyncValue<List<SyncLog>> logsAsync) {
    return logsAsync.when(
      data: (logs) {
        if (logs.isEmpty) {
          return const Center(
            child: Text('No sync logs yet'),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Sync History',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: logs.length,
                itemBuilder: (context, index) {
                  final log = logs[index];
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _getSyncStatusColor(log.syncStatus),
                        child: Icon(
                          _getSyncStatusIcon(log.syncStatus),
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      title: Text('${log.entityType} #${log.entityId}'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Status: ${log.syncStatus}'),
                          if (log.syncedAt != null)
                            Text(
                              'Synced: ${_formatDateTime(log.syncedAt!)}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          if (log.errorMessage != null)
                            Text(
                              'Error: ${log.errorMessage}',
                              style: const TextStyle(color: Colors.red, fontSize: 12),
                            ),
                        ],
                      ),
                      isThreeLine: true,
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }

  Future<void> _toggleServer() async {
    final vpnService = ref.read(vpnSyncServiceProvider);

    setState(() => _isSyncing = true);

    try {
      if (_isServerRunning) {
        await vpnService.stopSyncServer();
        setState(() {
          _isServerRunning = false;
          _lastSyncMessage = 'Server stopped';
        });
      } else {
        final success = await vpnService.startSyncServer();
        setState(() {
          _isServerRunning = success;
          _lastSyncMessage = success
              ? 'Server started on port 8888'
              : 'Failed to start server';
        });
      }
    } catch (e) {
      setState(() {
        _lastSyncMessage = 'Error: $e';
      });
    } finally {
      setState(() => _isSyncing = false);
    }
  }

  Future<void> _performSync(Store store, String type) async {
    if (store.vpnAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('VPN address not configured')),
      );
      return;
    }

    setState(() => _isSyncing = true);

    try {
      final vpnService = ref.read(vpnSyncServiceProvider);
      Map<String, dynamic> result;

      if (type == 'pull') {
        result = await vpnService.pullUpdates(
          serverVpnAddress: store.vpnAddress!,
          serverPort: store.syncPort ?? 8888,
          storeId: store.id,
          lastSyncAt: store.lastSyncAt,
        );
      } else if (type == 'push') {
        result = await vpnService.pushChanges(
          serverVpnAddress: store.vpnAddress!,
          serverPort: store.syncPort ?? 8888,
          storeId: store.id,
        );
      } else {
        // Full sync: pull then push
        result = await vpnService.pullUpdates(
          serverVpnAddress: store.vpnAddress!,
          serverPort: store.syncPort ?? 8888,
          storeId: store.id,
          lastSyncAt: store.lastSyncAt,
        );

        if (result['success'] == true) {
          result = await vpnService.pushChanges(
            serverVpnAddress: store.vpnAddress!,
            serverPort: store.syncPort ?? 8888,
            storeId: store.id,
          );
        }
      }

      setState(() {
        _lastSyncMessage = result['success'] == true
            ? 'Sync completed successfully'
            : 'Sync failed: ${result['error']}';
        _lastSyncTime = DateTime.now();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_lastSyncMessage!)),
        );
      }
    } catch (e) {
      setState(() {
        _lastSyncMessage = 'Error: $e';
        _lastSyncTime = DateTime.now();
      });
    } finally {
      setState(() => _isSyncing = false);
    }
  }

  Color _getSyncStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'success':
      case 'processed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'error':
      case 'failed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getSyncStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'success':
      case 'processed':
        return Icons.check_circle;
      case 'pending':
        return Icons.pending;
      case 'error':
      case 'failed':
        return Icons.error;
      default:
        return Icons.sync;
    }
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
