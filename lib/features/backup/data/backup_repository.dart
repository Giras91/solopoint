import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/database/database.dart';

final backupRepositoryProvider = Provider<BackupRepository>((ref) {
  final database = ref.watch(databaseProvider);
  return BackupRepository(database);
});

class BackupItem {
  final String id;
  final String filename;
  final int fileSize;
  final DateTime createdAt;
  final bool isRestored;

  BackupItem({
    required this.id,
    required this.filename,
    required this.fileSize,
    required this.createdAt,
    required this.isRestored,
  });
}

class BackupSummary {
  final int totalBackups;
  final int latestBackupSize;
  final DateTime? lastBackupTime;
  final String? lastBackupStatus;

  BackupSummary({
    required this.totalBackups,
    required this.latestBackupSize,
    required this.lastBackupTime,
    required this.lastBackupStatus,
  });
}

class BackupRepository {
  final AppDatabase _database;

  BackupRepository(this._database);

  /// Create and save a local backup
  Future<BackupItem> createAndUploadBackup() async {
    try {
      final timestamp = DateTime.now();
      final filename = 'solopoint_backup_${DateFormat('yyyyMMdd_HHmmss').format(timestamp)}.zip';

      // Get directories
      final docsDir = await getApplicationDocumentsDirectory();
      final backupDir = Directory('${docsDir.path}/backups');
      await backupDir.create(recursive: true);

      // Create temporary backup directory
      final tempDir = await getTemporaryDirectory();
      final tempBackupDir = Directory('${tempDir.path}/backup_${timestamp.millisecondsSinceEpoch}');
      await tempBackupDir.create(recursive: true);

      // Copy database file to backup directory
      final dbFile = File('${docsDir.path}/solopoint.db');
      if (await dbFile.exists()) {
        await dbFile.copy('${tempBackupDir.path}/solopoint.db');
      }

      // Create zip file
      final zipPath = '${backupDir.path}/$filename';
      final zipFile = File(zipPath);
      final encoder = ZipFileEncoder();
      encoder.create(zipFile.path);
      encoder.addDirectory(tempBackupDir);
      encoder.close();

      // Get file size
      final fileSize = await zipFile.length();

      // Save metadata
      await _saveBackupMetadata(filename, fileSize, timestamp);

      // Cleanup temp directory
      await tempBackupDir.delete(recursive: true);

      return BackupItem(
        id: filename,
        filename: filename,
        fileSize: fileSize,
        createdAt: timestamp,
        isRestored: false,
      );
    } catch (e) {
      throw Exception('Backup failed: $e');
    }
  }

  /// Retrieve backup history from local storage
  Future<List<BackupItem>> getBackupHistory() async {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final backupDir = Directory('${docsDir.path}/backups');

      if (!await backupDir.exists()) {
        return [];
      }

      List<BackupItem> backups = [];
      final files = backupDir.listSync();

      for (final file in files) {
        if (file is File && file.path.endsWith('.zip')) {
          final stat = await file.stat();
          final filename = file.path.split('/').last;
          
          // Parse date from filename
          final dateStr = filename
              .replaceAll('solopoint_backup_', '')
              .replaceAll('.zip', '');
          
          try {
            final createdAt = DateFormat('yyyyMMdd_HHmmss').parse(dateStr);
            backups.add(
              BackupItem(
                id: filename,
                filename: filename,
                fileSize: stat.size,
                createdAt: createdAt,
                isRestored: false,
              ),
            );
          } catch (e) {
            // Skip files with invalid date format
            continue;
          }
        }
      }

      // Sort by date descending
      backups.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return backups;
    } catch (e) {
      throw Exception('Failed to retrieve backup history: $e');
    }
  }

  /// Download and restore a backup
  Future<void> restoreBackup(String backupId) async {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final backupDir = Directory('${docsDir.path}/backups');
      final backupFile = File('${backupDir.path}/$backupId');

      if (!await backupFile.exists()) {
        throw Exception('Backup file not found');
      }

      // Extract zip
      final bytes = backupFile.readAsBytesSync();
      final archive = ZipDecoder().decodeBytes(bytes);

      // Extract database file
      for (final file in archive) {
        if (file.name.endsWith('solopoint.db')) {
          final data = file.content as List<int>;
          final restored = File('${docsDir.path}/solopoint.db');
          await restored.writeAsBytes(data);
          break;
        }
      }

      // Update metadata
      await _updateRestoreMetadata(backupId);
    } catch (e) {
      throw Exception('Restore failed: $e');
    }
  }

  /// Get backup summary statistics
  Future<BackupSummary> getBackupSummary() async {
    try {
      final backups = await getBackupHistory();
      if (backups.isEmpty) {
        return BackupSummary(
          totalBackups: 0,
          latestBackupSize: 0,
          lastBackupTime: null,
          lastBackupStatus: 'No backups yet',
        );
      }

      final latest = backups.first;
      return BackupSummary(
        totalBackups: backups.length,
        latestBackupSize: latest.fileSize,
        lastBackupTime: latest.createdAt,
        lastBackupStatus: 'Successfully backed up',
      );
    } catch (e) {
      return BackupSummary(
        totalBackups: 0,
        latestBackupSize: 0,
        lastBackupTime: null,
        lastBackupStatus: 'Error: Unable to retrieve backups',
      );
    }
  }

  /// Delete a backup from local storage
  Future<void> deleteBackup(String backupId) async {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final backupDir = Directory('${docsDir.path}/backups');
      final backupFile = File('${backupDir.path}/$backupId');

      if (await backupFile.exists()) {
        await backupFile.delete();
      }
    } catch (e) {
      throw Exception('Failed to delete backup: $e');
    }
  }

  /// Save local backup metadata to database
  Future<void> _saveBackupMetadata(String filename, int fileSize, DateTime createdAt) async {
    try {
      await _database.into(_database.settings).insert(
        SettingsCompanion.insert(
          key: 'last_backup_time',
          value: createdAt.toIso8601String(),
        ),
        mode: InsertMode.insertOrReplace,
      );
    } catch (e) {
      // Non-critical, continue even if metadata save fails
    }
  }

  /// Update restore metadata
  Future<void> _updateRestoreMetadata(String backupId) async {
    try {
      await _database.into(_database.settings).insert(
        SettingsCompanion.insert(
          key: 'last_restore_time',
          value: DateTime.now().toIso8601String(),
        ),
        mode: InsertMode.insertOrReplace,
      );
    } catch (e) {
      // Non-critical
    }
  }
}
