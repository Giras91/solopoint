import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import '../../../core/database/database.dart';
import '../store_repository.dart';
import '../store_providers.dart';

class StoreManagementScreen extends ConsumerWidget {
  const StoreManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storesAsync = ref.watch(storeListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Store Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showStoreDialog(context, ref),
          ),
        ],
      ),
      body: storesAsync.when(
        data: (stores) {
          if (stores.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.store, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No stores configured'),
                  Text('Tap + to add your first store'),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: stores.length,
            itemBuilder: (context, index) {
              final store = stores[index];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: store.isMainTerminal
                        ? Colors.blue
                        : Colors.green,
                    child: Icon(
                      store.isMainTerminal ? Icons.dns : Icons.store,
                      color: Colors.white,
                    ),
                  ),
                  title: Text(
                    store.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Code: ${store.code}'),
                      if (store.vpnAddress != null)
                        Text('VPN: ${store.vpnAddress}:${store.syncPort}'),
                      if (store.lastSyncAt != null)
                        Text(
                          'Last Sync: ${_formatDateTime(store.lastSyncAt!)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: store.isActive ? Colors.green : Colors.grey,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          store.isActive ? 'Active' : 'Inactive',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'edit') {
                            _showStoreDialog(context, ref, store: store);
                          } else if (value == 'deactivate') {
                            _deactivateStore(context, ref, store.id);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Text('Edit'),
                          ),
                          if (store.isActive)
                            const PopupMenuItem(
                              value: 'deactivate',
                              child: Text('Deactivate'),
                            ),
                        ],
                      ),
                    ],
                  ),
                  isThreeLine: true,
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  void _showStoreDialog(BuildContext context, WidgetRef ref, {Store? store}) {
    showDialog(
      context: context,
      builder: (context) => StoreFormDialog(store: store),
    );
  }

  Future<void> _deactivateStore(BuildContext context, WidgetRef ref, int storeId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deactivate Store'),
        content: const Text('Are you sure you want to deactivate this store?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(storeRepositoryProvider).deactivateStore(storeId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Store deactivated')),
        );
      }
    }
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class StoreFormDialog extends ConsumerStatefulWidget {
  final Store? store;

  const StoreFormDialog({super.key, this.store});

  @override
  ConsumerState<StoreFormDialog> createState() => _StoreFormDialogState();
}

class _StoreFormDialogState extends ConsumerState<StoreFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _codeController;
  late TextEditingController _nameController;
  late TextEditingController _addressController;
  late TextEditingController _vpnAddressController;
  late TextEditingController _syncPortController;
  bool _isMainTerminal = false;
  bool _isActive = true;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController(text: widget.store?.code ?? '');
    _nameController = TextEditingController(text: widget.store?.name ?? '');
    _addressController = TextEditingController(text: widget.store?.address ?? '');
    _vpnAddressController = TextEditingController(text: widget.store?.vpnAddress ?? '');
    _syncPortController = TextEditingController(
      text: widget.store?.syncPort.toString() ?? '8888',
    );
    _isMainTerminal = widget.store?.isMainTerminal ?? false;
    _isActive = widget.store?.isActive ?? true;
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _addressController.dispose();
    _vpnAddressController.dispose();
    _syncPortController.dispose();
    super.dispose();
  }

  Future<void> _saveStore() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isProcessing = true);

    try {
      final repository = ref.read(storeRepositoryProvider);

      final storeCompanion = StoresCompanion(
        id: widget.store != null ? drift.Value(widget.store!.id) : const drift.Value.absent(),
        code: drift.Value(_codeController.text),
        name: drift.Value(_nameController.text),
        address: drift.Value(_addressController.text.isNotEmpty ? _addressController.text : null),
        isMainTerminal: drift.Value(_isMainTerminal),
        isActive: drift.Value(_isActive),
        vpnAddress: drift.Value(
          _vpnAddressController.text.isNotEmpty ? _vpnAddressController.text : null,
        ),
        syncPort: drift.Value(int.tryParse(_syncPortController.text) ?? 8888),
        createdAt: widget.store != null
            ? drift.Value(widget.store!.createdAt)
            : drift.Value(DateTime.now()),
      );

      if (widget.store != null) {
        await repository.updateStore(storeCompanion);
      } else {
        await repository.createStore(storeCompanion);
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.store != null ? 'Store updated' : 'Store created',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving store: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.store != null ? 'Edit Store' : 'Add Store',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _codeController,
                decoration: const InputDecoration(
                  labelText: 'Store Code',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Store Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Address (Optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                title: const Text('Main Terminal (Server)'),
                subtitle: const Text('This terminal will act as sync server'),
                value: _isMainTerminal,
                onChanged: (value) => setState(() => _isMainTerminal = value ?? false),
              ),
              if (!_isMainTerminal) ...[
                const SizedBox(height: 8),
                TextFormField(
                  controller: _vpnAddressController,
                  decoration: const InputDecoration(
                    labelText: 'VPN Address (Main Terminal)',
                    hintText: '192.168.1.100',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _syncPortController,
                  decoration: const InputDecoration(
                    labelText: 'Sync Port',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ],
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isProcessing
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isProcessing ? null : _saveStore,
                    child: Text(_isProcessing ? 'Saving...' : 'Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
