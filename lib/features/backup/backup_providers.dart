import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'data/backup_repository.dart';

final backupHistoryProvider = FutureProvider<List<BackupItem>>((ref) async {
  final repository = ref.watch(backupRepositoryProvider);
  return repository.getBackupHistory();
});

final backupSummaryProvider = FutureProvider<BackupSummary>((ref) async {
  final repository = ref.watch(backupRepositoryProvider);
  return repository.getBackupSummary();
});

final backupStatusProvider = StateProvider<String>((ref) => 'Ready to backup');

final lastSyncTimeProvider = StateProvider<DateTime?>((ref) => null);

final autoBackupEnabledProvider = StateProvider<bool>((ref) => false);

final backupCreatingProvider = StateProvider<bool>((ref) => false);

final backupRestoringProvider = StateProvider<bool>((ref) => false);

final selectedBackupProvider = StateProvider<BackupItem?>((ref) => null);

