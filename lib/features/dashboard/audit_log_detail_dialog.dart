import 'package:flutter/material.dart';
import '../../core/database/database.dart';
import 'dart:convert';

class AuditLogDetailDialog extends StatelessWidget {
  final AuditJournalData log;
  final User? user;

  const AuditLogDetailDialog({
    required this.log,
    this.user,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final details = _parseDetails();

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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Audit Log Details',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: colorScheme.onPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Event: ${log.action}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onPrimary,
                    ),
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
                  // Basic info
                  _buildInfoCard(
                    context,
                    'Basic Information',
                    [
                      _buildInfoRow('Action', log.action),
                      _buildInfoRow('Entity Type', log.entityType),
                      _buildInfoRow('Entity ID', log.entityId?.toString() ?? 'N/A'),
                      _buildInfoRow(
                        'User',
                        user?.name ?? 'User #${log.userId}',
                      ),
                      _buildInfoRow(
                        'Timestamp',
                        _formatDateTime(log.timestamp),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Additional details
                  if (details.isNotEmpty)
                    _buildInfoCard(
                      context,
                      'Additional Details',
                      details
                          .entries
                          .map((e) => _buildInfoRow(e.key, e.value))
                          .toList(),
                    ),
                ],
              ),
            ),

            // Close button
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
                label: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context,
    String title,
    List<Widget> children,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: SelectableText(
              value ?? 'N/A',
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return 'N/A';
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
  }

  Map<String, String> _parseDetails() {
    final details = <String, String>{};

    if (log.details == null || log.details!.isEmpty) {
      return details;
    }

    try {
      // Try to parse as JSON
      final jsonData = jsonDecode(log.details!);
      if (jsonData is Map) {
        jsonData.forEach((key, value) {
          details[key] = value.toString();
        });
      }
    } catch (e) {
      // If not JSON, just return as is
      details['Details'] = log.details!;
    }

    return details;
  }
}
