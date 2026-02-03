import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:drift/drift.dart' as drift;
import '../../core/database/database.dart';
import '../auth/user_repository.dart';
import '../auth/attendance_repository.dart';

class StaffDetailDialog extends ConsumerStatefulWidget {
  final User user;

  const StaffDetailDialog({
    required this.user,
    super.key,
  });

  @override
  ConsumerState<StaffDetailDialog> createState() => _StaffDetailDialogState();
}

class _StaffDetailDialogState extends ConsumerState<StaffDetailDialog> {
  late TextEditingController _nameController;
  late TextEditingController _pinController;
  String? _selectedRole;
  bool _isActive = true;
  bool _isEditing = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.name);
    _pinController = TextEditingController();
    _selectedRole = widget.user.role;
    _isActive = widget.user.isActive;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  void _handleSave() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name cannot be empty')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final userRepo = ref.read(userRepositoryProvider);
      
      // Update user with companion object
      await userRepo.updateUser(
        widget.user.id,
        UsersCompanion(
          name: drift.Value(_nameController.text),
          role: _selectedRole != null ? drift.Value(_selectedRole!) : const drift.Value.absent(),
          isActive: drift.Value(_isActive),
          pin: _pinController.text.isNotEmpty ? drift.Value(_pinController.text) : const drift.Value.absent(),
        ),
      );

      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Staff updated successfully')),
        );
        setState(() => _isEditing = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  void _handleDeactivate() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deactivate Staff?'),
        content: Text('Are you sure you want to deactivate ${widget.user.name}?'),
        actions: [
          TextButton(
            onPressed: () => context.pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => context.pop(true),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ref.read(userRepositoryProvider).updateUser(
          widget.user.id,
          UsersCompanion(
            isActive: drift.Value(false),
          ),
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Staff deactivated')),
          );
          context.pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${e.toString()}')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Dialog(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.primary,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: colorScheme.onPrimary,
                    child: Text(
                      widget.user.name.isNotEmpty
                          ? widget.user.name[0].toUpperCase()
                          : '?',
                      style: TextStyle(color: colorScheme.primary),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.user.name,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: colorScheme.onPrimary,
                          ),
                        ),
                        Text(
                          'ID: ${widget.user.id}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!_isEditing)
                    IconButton(
                      icon: const Icon(Icons.edit),
                      color: colorScheme.onPrimary,
                      onPressed: () => setState(() => _isEditing = true),
                    ),
                ],
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Name field
                  TextField(
                    controller: _nameController,
                    enabled: _isEditing,
                    decoration: InputDecoration(
                      labelText: 'Name',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: const Icon(Icons.person),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Role dropdown
                  DropdownButtonFormField<String>(
                    initialValue: _selectedRole,
                    onChanged: _isEditing
                        ? (value) => setState(() => _selectedRole = value)
                        : null,
                    decoration: InputDecoration(
                      labelText: 'Role',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: const Icon(Icons.shield),
                    ),
                    items: [
                      'admin',
                      'manager',
                      'cashier',
                      'staff',
                    ]
                        .map((role) => DropdownMenuItem(
                          value: role,
                          child: Text(role),
                        ))
                        .toList(),
                  ),
                  const SizedBox(height: 12),

                  // PIN field (only show when editing)
                  if (_isEditing)
                    TextField(
                      controller: _pinController,
                      decoration: InputDecoration(
                        labelText: 'New PIN (leave blank to keep current)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: const Icon(Icons.lock),
                        hintText: '4-6 digits',
                      ),
                      obscureText: true,
                      maxLength: 6,
                    ),
                  if (_isEditing) const SizedBox(height: 12),

                  // Active status toggle
                  SwitchListTile(
                    title: const Text('Active'),
                    value: _isActive,
                    onChanged: _isEditing
                        ? (value) => setState(() => _isActive = value)
                        : null,
                    subtitle: Text(_isActive ? 'Can log in' : 'Cannot log in'),
                  ),
                  const SizedBox(height: 12),

                  // Stats section
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Shift Information',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 8),
                        _buildStatRow('Status', _buildStatusWidget()),
                        const SizedBox(height: 8),
                        _buildStatRow(
                          'Joined',
                          Text(
                            widget.user.createdAt.toString().split(' ')[0],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Actions
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (_isEditing)
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _isEditing = false;
                          _nameController.text = widget.user.name;
                          _selectedRole = widget.user.role;
                          _isActive = widget.user.isActive;
                          _pinController.clear();
                        });
                      },
                      child: const Text('Cancel'),
                    ),
                  const SizedBox(width: 8),
                  if (_isEditing)
                    ElevatedButton.icon(
                      onPressed: _isSaving ? null : _handleSave,
                      icon: _isSaving
                          ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(Icons.save),
                      label: const Text('Save'),
                    ),
                  if (!_isEditing) ...[
                    ElevatedButton.icon(
                      onPressed: _handleDeactivate,
                      icon: const Icon(Icons.block),
                      label: const Text('Deactivate'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => context.pop(),
                      icon: const Icon(Icons.close),
                      label: const Text('Close'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, Widget value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        value,
      ],
    );
  }

  Widget _buildStatusWidget() {
    final attendanceRepo = ref.watch(attendanceRepositoryProvider);
    
    return FutureBuilder<AttendanceLog?>(
      future: attendanceRepo.getUserCurrentStatus(widget.user.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 16,
            width: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          final lastLog = snapshot.data!;
          Color statusColor;
          String statusText;

          switch (lastLog.action) {
            case 'clock_in':
              statusColor = Colors.green;
              statusText = 'Clocked In';
              break;
            case 'break_start':
              statusColor = Colors.orange;
              statusText = 'On Break';
              break;
            case 'clock_out':
              statusColor = Colors.red;
              statusText = 'Clocked Out';
              break;
            default:
              statusColor = Colors.grey;
              statusText = 'Unknown';
          }

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withAlpha(51),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              statusText,
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          );
        }

        final greyColor = Colors.grey[600];
        return Text(
          'No Status',
          style: TextStyle(color: greyColor),
        );
      },
    );
  }
}
