import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive_api;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/database/database.dart';
import 'backup_encryption_service.dart';

final googleDriveServiceProvider = Provider<GoogleDriveBackupService>((ref) {
  final database = ref.watch(databaseProvider);
  return GoogleDriveBackupService(database);
});

/// Service for backing up and restoring the SoloPoint database to/from Google Drive
/// 
/// Features:
/// - Authenticate with Google using drive.appdata scope (private app folder)
/// - Encrypt database before uploading for security
/// - Verify integrity using MD5 checksums
/// - Admin-only operations with confirmation dialogs
class GoogleDriveBackupService {
  final AppDatabase _database;

  // Private app folder scope - files are inaccessible to other apps
  static const String _driveAppDataScope = 'https://www.googleapis.com/auth/drive.appdata';
  static const String _serverClientId =
      '717349630599-ndh7ugfd4agpajjunmhtcqlpa6pgmf2o.apps.googleusercontent.com';

  late final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      _driveAppDataScope,
    ],
    serverClientId: _serverClientId,
  );

  static const String _backupFileName = 'solopoint_backup.db.encrypted';
  static const String _checksumFileName = 'solopoint_backup.md5';

  GoogleDriveBackupService(this._database);

  /// Get the local database file path
  Future<File> _getDatabaseFile() async {
    final docDir = await getApplicationDocumentsDirectory();
    return File(File(docDir.path).path + Platform.pathSeparator + 'solopoint.sqlite');
  }

  /// Authenticate with Google
  /// Returns true if successful, false if user cancelled
  Future<bool> authenticate() async {
    try {
      final account = await _googleSignIn.signInSilently();
      if (account != null) {
        return true;
      }

      final signedInAccount = await _googleSignIn.signIn();
      return signedInAccount != null;
    } catch (e) {
      debugPrint('Authentication error: $e');
      return false;
    }
  }

  /// Sign out from Google
  Future<void> signOut() async {
    await _googleSignIn.signOut();
  }

  /// Get current signed-in account
  GoogleSignInAccount? get currentAccount => _googleSignIn.currentUser;

  /// Check if user is signed in
  bool get isSignedIn => _googleSignIn.currentUser != null;

  /// Backup database to Google Drive (encrypted)
  /// Returns success message or throws exception
  Future<String> backupDatabase() async {
    try {
      // Ensure authenticated
      final authenticated = await authenticate();
      if (!authenticated) {
        throw Exception('Not authenticated with Google');
      }

      final account = _googleSignIn.currentUser;
      if (account == null) {
        throw Exception('No signed-in account');
      }

      // Get database file
      final dbFile = await _getDatabaseFile();
      if (!dbFile.existsSync()) {
        throw Exception('Database file not found at ${dbFile.path}');
      }

      // Encrypt database
      final encryptedData = await BackupEncryptionService.encryptFile(dbFile);
      final checksum = BackupEncryptionService.calculateBytesChecksum(encryptedData);

      // Initialize Drive API client
      final authHeaders = await account.authHeaders;
      final client = _AuthorizedClient(authHeaders);
      final driveApi = drive_api.DriveApi(client);

      // Check if backup already exists in appDataFolder
      final existingFiles = await driveApi.files.list(
        spaces: 'appDataFolder',
        q: "name = '$_backupFileName'",
        $fields: 'files(id, name, modifiedTime)',
      );

      late String fileId;

      if (existingFiles.files != null && existingFiles.files!.isNotEmpty) {
        // Update existing backup
        fileId = existingFiles.files!.first.id!;
        debugPrint('Updating existing backup file: $fileId');

        // Delete old file and create new one (simpler than updating with stream)
        await driveApi.files.delete(fileId);
      }

      // Create new backup file
      final mediaUpload = drive_api.Media(Stream.value(encryptedData), encryptedData.length);

      final file = drive_api.File()
        ..name = _backupFileName
        ..parents = ['appDataFolder'];

      final uploadedFile = await driveApi.files.create(
        file,
        uploadMedia: mediaUpload,
        $fields: 'id, name, modifiedTime, size',
      );

      // Upload checksum file
      final checksumData = checksum.codeUnits;
      final checksumMedia = drive_api.Media(Stream.value(checksumData), checksumData.length);
      final checksumFileObj = drive_api.File()
        ..name = _checksumFileName
        ..parents = ['appDataFolder'];

      await driveApi.files.create(
        checksumFileObj,
        uploadMedia: checksumMedia,
      );

      final timestamp = uploadedFile.modifiedTime?.toLocal().toString() ?? 'unknown';
      final sizeBytes = (uploadedFile.size as int?) ?? 0;
      final sizeKB = sizeBytes / 1024;

      return 'Backup successful!\n'
          'File: ${uploadedFile.name}\n'
          'Size: ${sizeKB.toStringAsFixed(2)} KB\n'
          'Time: $timestamp';
    } finally {
      // Cleanup
    }
  }

  /// Restore database from Google Drive (decrypted)
  /// Requires user confirmation before overwriting local data
  /// Returns success message or throws exception
  Future<String> restoreDatabase() async {
    try {
      // Ensure authenticated
      final authenticated = await authenticate();
      if (!authenticated) {
        throw Exception('Not authenticated with Google');
      }

      final account = _googleSignIn.currentUser;
      if (account == null) {
        throw Exception('No signed-in account');
      }

      // Initialize Drive API client
      final authHeaders = await account.authHeaders;
      final client = _AuthorizedClient(authHeaders);
      final driveApi = drive_api.DriveApi(client);

      // Find backup file in appDataFolder
      final files = await driveApi.files.list(
        spaces: 'appDataFolder',
        q: "name = '$_backupFileName'",
        $fields: 'files(id, name, modifiedTime, size)',
      );

      if (files.files == null || files.files!.isEmpty) {
        throw Exception('No backup found on Google Drive');
      }

      final backupFile = files.files!.first;
      debugPrint('Found backup file: ${backupFile.id}');

      // Download checksum
      final checksumFiles = await driveApi.files.list(
        spaces: 'appDataFolder',
        q: "name = '$_checksumFileName'",
        $fields: 'files(id)',
      );

      String? expectedChecksum;
      if (checksumFiles.files != null && checksumFiles.files!.isNotEmpty) {
        try {
          final checksumData = await driveApi.files.get(
            checksumFiles.files!.first.id!,
            downloadOptions: drive_api.DownloadOptions.fullMedia,
          ) as drive_api.Media;

          final checksumBytes = <int>[];
          await checksumData.stream.forEach((chunk) {
            checksumBytes.addAll(chunk);
          });
          expectedChecksum = String.fromCharCodes(checksumBytes);
          debugPrint('Downloaded checksum: $expectedChecksum');
        } catch (e) {
          debugPrint('Warning: Could not download checksum: $e');
        }
      }

      // Download encrypted backup
      final encryptedData = <int>[];
      final media = await driveApi.files.get(
        backupFile.id!,
        downloadOptions: drive_api.DownloadOptions.fullMedia,
      ) as drive_api.Media;

      await media.stream.forEach((chunk) {
        encryptedData.addAll(chunk);
      });

      debugPrint('Downloaded ${encryptedData.length} bytes');

      // Verify checksum if available
      if (expectedChecksum != null) {
        final calculatedChecksum =
            BackupEncryptionService.calculateBytesChecksum(encryptedData);
        if (!BackupEncryptionService.verifyChecksum(encryptedData, expectedChecksum)) {
          throw Exception(
            'Backup integrity check failed!\n'
            'Expected: $expectedChecksum\n'
            'Got: $calculatedChecksum\n'
            'The file may be corrupted.',
          );
        }
        debugPrint('Checksum verified: $calculatedChecksum');
      }

      // Decrypt backup
      final decryptedData = BackupEncryptionService.decryptBytes(encryptedData);

      // Close database connection
      await _database.close();

      // Overwrite local database file
      final dbFile = await _getDatabaseFile();
      await dbFile.writeAsBytes(decryptedData);

      // Reopen database
      // Note: In a real app, you'd reinitialize the database provider
      // For now, we just report success

      return 'Restore successful!\n'
          'Backup from: ${backupFile.modifiedTime?.toLocal().toString() ?? "unknown"}\n'
          'Size: ${(decryptedData.length / 1024).toStringAsFixed(2)} KB\n'
          'Please restart the app to complete restore.';
    } finally {
      // Cleanup
    }
  }

  /// Get backup metadata from Google Drive
  Future<BackupMetadata?> getBackupMetadata() async {
    try {
      final authenticated = await authenticate();
      if (!authenticated) return null;

      final account = _googleSignIn.currentUser;
      if (account == null) return null;

      final authHeaders = await account.authHeaders;
      final client = _AuthorizedClient(authHeaders);
      final driveApi = drive_api.DriveApi(client);

      final files = await driveApi.files.list(
        spaces: 'appDataFolder',
        q: "name = '$_backupFileName'",
        $fields: 'files(id, name, modifiedTime, size, md5Checksum)',
      );

      if (files.files == null || files.files!.isEmpty) {
        return null;
      }

      final file = files.files!.first;

      return BackupMetadata(
        fileName: file.name ?? 'Unknown',
        lastModified: file.modifiedTime ?? DateTime.now(),
        sizeBytes: (file.size as int?) ?? 0,
        checksum: file.md5Checksum,
      );
    } catch (e) {
      debugPrint('Error getting backup metadata: $e');
      return null;
    }
  }
}

/// Wrapper to make GoogleSignInAccount's authHeaders work with googleapis
class _AuthorizedClient extends http.BaseClient {
  final Map<String, String> _headers;

  _AuthorizedClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _sendInternal(request);
  }

  Future<http.StreamedResponse> _sendInternal(http.BaseRequest request) async {
    final response = await http.Client().send(request);
    return http.StreamedResponse(
      response.stream,
      response.statusCode,
      contentLength: response.contentLength,
      request: response.request,
      headers: response.headers,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
      reasonPhrase: response.reasonPhrase,
    );
  }
}

/// Metadata about a backup file
class BackupMetadata {
  final String fileName;
  final DateTime lastModified;
  final int sizeBytes;
  final String? checksum;

  BackupMetadata({
    required this.fileName,
    required this.lastModified,
    required this.sizeBytes,
    this.checksum,
  });

  String get sizeMB => (sizeBytes / (1024 * 1024)).toStringAsFixed(2);

  String get formattedDate =>
      '${lastModified.year}-${lastModified.month.toString().padLeft(2, '0')}-${lastModified.day.toString().padLeft(2, '0')} '
      '${lastModified.hour.toString().padLeft(2, '0')}:${lastModified.minute.toString().padLeft(2, '0')}';
}
