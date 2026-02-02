import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import '../../core/database/database.dart';

// StateNotifier for managing user authentication
class AuthNotifier extends StateNotifier<User?> {
  final AppDatabase database;

  AuthNotifier(this.database) : super(null) {
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    // Check if there's a logged-in user stored
    // For now, we'll just keep the state as null until explicitly logged in
  }

  /// Authenticate user with PIN
  Future<bool> login(String pin) async {
    try {
      final user = await (database.select(database.users)
          ..where((u) => u.pin.equals(pin) & u.isActive.equals(true)))
          .getSingleOrNull();

      if (user != null) {
        state = user;
        return true;
      }
      return false;
    } catch (e) {
      print('Login error: $e');
      return false;
    }
  }

  /// Logout current user
  void logout() {
    state = null;
  }

  /// Create a new user (admin only)
  Future<void> createUser({
    required String name,
    required String pin,
    required String role,
  }) async {
    await database.into(database.users).insert(UsersCompanion(
      name: Value(name),
      pin: Value(pin),
      role: Value(role),
      isActive: const Value(true),
    ));
  }

  /// Get all users
  Stream<List<User>> watchAllUsers() {
    return database.select(database.users).watch();
  }

  /// Update user
  Future<void> updateUser(User user) async {
    await database.update(database.users).replace(user);
  }

  /// Delete user
  Future<void> deleteUser(int userId) async {
    await (database.delete(database.users)..where((u) => u.id.equals(userId))).go();
  }
}

// Provider for the auth notifier
final authProvider = StateNotifierProvider<AuthNotifier, User?>((ref) {
  final db = ref.watch(databaseProvider);
  return AuthNotifier(db);
});

// Stream of active users for login selection
final activeUsersProvider = StreamProvider<List<User>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.users)..where((u) => u.isActive.equals(true))).watch();
});

// Selector for checking if user is logged in
final isLoggedInProvider = Provider<bool>((ref) {
  return ref.watch(authProvider) != null;
});

// Selector for current user role
final userRoleProvider = Provider<String?>((ref) {
  return ref.watch(authProvider)?.role;
});

// Check if logged in user is admin
final isAdminProvider = Provider<bool>((ref) {
  final role = ref.watch(userRoleProvider);
  return role == 'admin';
});
