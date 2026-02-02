import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'services/google_drive_backup_service.dart';

/// Provider for Google Drive backup service
// Already defined in google_drive_backup_service.dart
// See: googleDriveServiceProvider

/// Provider for Google Sign-In account state
final googleSignInAccountProvider = StreamProvider<GoogleSignInAccount?>((ref) {
  final service = ref.watch(googleDriveServiceProvider);
  return Stream.value(service.currentAccount);
});

/// Provider for checking if user is signed in
final isGoogleSignedInProvider = StreamProvider<bool>((ref) {
  final account = ref.watch(googleSignInAccountProvider);
  return account.when(
    data: (account) => Stream.value(account != null),
    loading: () => Stream.value(false),
    error: (_, __) => Stream.value(false),
  );
});

/// Provider for backup metadata
final backupMetadataProvider = FutureProvider<BackupMetadata?>((ref) async {
  final service = ref.watch(googleDriveServiceProvider);
  return service.getBackupMetadata();
});

/// State notifier for backup operations (loading, error, success states)
class BackupStateNotifier extends StateNotifier<AsyncValue<String>> {
  final GoogleDriveBackupService _service;

  BackupStateNotifier(this._service) : super(const AsyncValue.data(''));

  /// Perform backup operation
  Future<void> performBackup() async {
    state = const AsyncValue.loading();
    try {
      final message = await _service.backupDatabase();
      state = AsyncValue.data(message);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Perform restore operation
  Future<void> performRestore() async {
    state = const AsyncValue.loading();
    try {
      final message = await _service.restoreDatabase();
      state = AsyncValue.data(message);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Sign in with Google
  Future<bool> signInWithGoogle() async {
    state = const AsyncValue.loading();
    try {
      final success = await _service.authenticate();
      if (success) {
        state = const AsyncValue.data('Signed in successfully');
      } else {
        state = AsyncValue.error('Sign-in cancelled', StackTrace.current);
      }
      return success;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Sign out from Google
  Future<void> signOut() async {
    try {
      await _service.signOut();
      state = const AsyncValue.data('Signed out');
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Reset state
  void reset() {
    state = const AsyncValue.data('');
  }
}

/// Provider for backup state management
final backupStateProvider =
    StateNotifierProvider<BackupStateNotifier, AsyncValue<String>>((ref) {
  final service = ref.watch(googleDriveServiceProvider);
  return BackupStateNotifier(service);
});

/// Provider to check if user is an admin (simplified - checks role)
/// In a real app, integrate with your auth system
final isAdminProvider = FutureProvider<bool>((ref) async {
  // TODO: Integrate with your actual auth system to check if user is admin
  // For now, returning false - will be implemented in UI integration
  return false;
});
