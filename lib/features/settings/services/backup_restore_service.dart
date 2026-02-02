import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../../../core/database/database.dart';

final backupRestoreServiceProvider = Provider<BackupRestoreService>((ref) {
  final db = ref.watch(databaseProvider);
  return BackupRestoreService(db);
});

class BackupRestoreService {
  final AppDatabase _db;

  BackupRestoreService(this._db);

  /// Create a backup of the current database
  Future<BackupResult> createBackup() async {
    try {
      // Get the database file path
      final dbFolder = await getApplicationDocumentsDirectory();
      final dbFile = File(p.join(dbFolder.path, 'solopoint.sqlite'));

      if (!await dbFile.exists()) {
        return BackupResult(
          success: false,
          message: 'Database file not found',
        );
      }

      // Create backup filename with timestamp
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final backupFileName = 'solopoint_backup_$timestamp.db';

      // Get external storage directory for backup
      final tempDir = await getTemporaryDirectory();
      final backupFile = File(p.join(tempDir.path, backupFileName));

      // Copy database file to backup location
      await dbFile.copy(backupFile.path);

      return BackupResult(
        success: true,
        message: 'Backup created successfully',
        filePath: backupFile.path,
        fileName: backupFileName,
      );
    } catch (e) {
      return BackupResult(
        success: false,
        message: 'Failed to create backup: $e',
      );
    }
  }

  /// Export backup and share via native share sheet
  Future<BackupResult> exportAndShareBackup() async {
    final backupResult = await createBackup();

    if (!backupResult.success || backupResult.filePath == null) {
      return backupResult;
    }

    try {
      // Share the backup file
      final file = XFile(backupResult.filePath!);
      await Share.shareXFiles(
        [file],
        subject: 'SoloPoint Database Backup',
        text: 'SoloPoint POS backup created on ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
      );

      return BackupResult(
        success: true,
        message: 'Backup exported successfully',
        filePath: backupResult.filePath,
        fileName: backupResult.fileName,
      );
    } catch (e) {
      return BackupResult(
        success: false,
        message: 'Failed to share backup: $e',
      );
    }
  }

  /// Restore database from a backup file
  Future<BackupResult> restoreFromBackup() async {
    try {
      // Let user pick a backup file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['db', 'sqlite', 'sqlite3'],
      );

      if (result == null || result.files.isEmpty) {
        return BackupResult(
          success: false,
          message: 'No file selected',
        );
      }

      final pickedFile = result.files.first;
      if (pickedFile.path == null) {
        return BackupResult(
          success: false,
          message: 'Invalid file path',
        );
      }

      // Close current database connection
      await _db.close();

      // Get database file path
      final dbFolder = await getApplicationDocumentsDirectory();
      final dbFile = File(p.join(dbFolder.path, 'solopoint.sqlite'));

      // Backup current database before restore (just in case)
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final preRestoreBackup = File(p.join(dbFolder.path, 'solopoint_pre_restore_$timestamp.db'));
      
      if (await dbFile.exists()) {
        await dbFile.copy(preRestoreBackup.path);
      }

      // Copy selected backup file to database location
      final backupFile = File(pickedFile.path!);
      await backupFile.copy(dbFile.path);

      return BackupResult(
        success: true,
        message: 'Database restored successfully. Please restart the app.',
        fileName: pickedFile.name,
      );
    } catch (e) {
      return BackupResult(
        success: false,
        message: 'Failed to restore backup: $e',
      );
    }
  }

  /// Get backup info (database size, record counts)
  Future<BackupInfo> getBackupInfo() async {
    try {
      final dbFolder = await getApplicationDocumentsDirectory();
      final dbFile = File(p.join(dbFolder.path, 'solopoint.sqlite'));

      final size = await dbFile.length();
      final sizeInMB = (size / (1024 * 1024)).toStringAsFixed(2);

      // Get record counts
      final productCount = await (_db.select(_db.products).get()).then((p) => p.length);
      final orderCount = await (_db.select(_db.orders).get()).then((o) => o.length);
      final customerCount = await (_db.select(_db.customers).get()).then((c) => c.length);

      return BackupInfo(
        databaseSize: sizeInMB,
        productCount: productCount,
        orderCount: orderCount,
        customerCount: customerCount,
        lastModified: await dbFile.lastModified(),
      );
    } catch (e) {
      return BackupInfo(
        databaseSize: '0',
        productCount: 0,
        orderCount: 0,
        customerCount: 0,
        lastModified: DateTime.now(),
      );
    }
  }

  /// Create automatic daily backup
  Future<BackupResult> createAutomaticBackup() async {
    try {
      final backupResult = await createBackup();
      
      if (!backupResult.success || backupResult.filePath == null) {
        return backupResult;
      }

      // Move to a dedicated auto-backup folder
      final dbFolder = await getApplicationDocumentsDirectory();
      final autoBackupDir = Directory(p.join(dbFolder.path, 'auto_backups'));
      
      if (!await autoBackupDir.exists()) {
        await autoBackupDir.create(recursive: true);
      }

      final sourceFile = File(backupResult.filePath!);
      final destFile = File(p.join(autoBackupDir.path, backupResult.fileName!));
      await sourceFile.copy(destFile.path);

      // Clean up old auto-backups (keep last 7 days)
      await _cleanupOldBackups(autoBackupDir);

      return BackupResult(
        success: true,
        message: 'Automatic backup created',
        filePath: destFile.path,
        fileName: backupResult.fileName,
      );
    } catch (e) {
      return BackupResult(
        success: false,
        message: 'Failed to create automatic backup: $e',
      );
    }
  }

  /// Clean up old automatic backups (keep last 7)
  Future<void> _cleanupOldBackups(Directory backupDir) async {
    try {
      final files = await backupDir.list().where((f) => f is File).toList();
      
      if (files.length <= 7) return;

      // Sort by modified date (oldest first)
      files.sort((a, b) {
        final aModified = (a as File).lastModifiedSync();
        final bModified = (b as File).lastModifiedSync();
        return aModified.compareTo(bModified);
      });

      // Delete oldest files
      final filesToDelete = files.take(files.length - 7);
      for (final file in filesToDelete) {
        await (file as File).delete();
      }
    } catch (e) {
      // Ignore cleanup errors
    }
  }
}

/// Result of a backup/restore operation
class BackupResult {
  final bool success;
  final String message;
  final String? filePath;
  final String? fileName;

  BackupResult({
    required this.success,
    required this.message,
    this.filePath,
    this.fileName,
  });
}

/// Information about the current database
class BackupInfo {
  final String databaseSize;
  final int productCount;
  final int orderCount;
  final int customerCount;
  final DateTime lastModified;

  BackupInfo({
    required this.databaseSize,
    required this.productCount,
    required this.orderCount,
    required this.customerCount,
    required this.lastModified,
  });
}
