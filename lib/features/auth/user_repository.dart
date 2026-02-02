import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import '../../core/database/database.dart';

final userRepositoryProvider = Provider<UserRepository>((ref) {
  final database = ref.watch(databaseProvider);
  return UserRepository(database);
});

class UserRepository {
  final AppDatabase _db;

  UserRepository(this._db);

  // Watch all users
  Stream<List<User>> watchAllUsers() {
    return (_db.select(_db.users)
          ..orderBy([(u) => OrderingTerm.asc(u.name)]))
        .watch();
  }

  // Get single user
  Future<User?> getUser(int id) {
    return (_db.select(_db.users)..where((u) => u.id.equals(id)))
        .getSingleOrNull();
  }

  // Get user by PIN
  Future<User?> getUserByPin(String pin) {
    return (_db.select(_db.users)
          ..where((u) => u.pin.equals(pin) & u.isActive.equals(true)))
        .getSingleOrNull();
  }

  // Create user
  Future<int> createUser(UsersCompanion user) {
    return _db.into(_db.users).insert(user);
  }

  // Update user
  Future<int> updateUser(int id, UsersCompanion user) {
    return (_db.update(_db.users)..where((u) => u.id.equals(id))).write(user);
  }

  // Delete user
  Future<int> deleteUser(int id) {
    return (_db.delete(_db.users)..where((u) => u.id.equals(id))).go();
  }

  // Toggle user active status
  Future<int> toggleUserStatus(int id, bool isActive) {
    return (_db.update(_db.users)..where((u) => u.id.equals(id)))
        .write(UsersCompanion(isActive: Value(isActive)));
  }

  // Change user PIN
  Future<int> changePin(int userId, String newPin) {
    return (_db.update(_db.users)..where((u) => u.id.equals(userId)))
        .write(UsersCompanion(
      pin: Value(newPin),
      updatedAt: Value(DateTime.now()),
    ));
  }

  // Validate PIN format (4-6 digits)
  bool isValidPin(String pin) {
    if (pin.length < 4 || pin.length > 6) return false;
    return int.tryParse(pin) != null;
  }

  // Check if PIN already exists
  Future<bool> pinExists(String pin, {int? excludeUserId}) async {
    final query = _db.select(_db.users)..where((u) => u.pin.equals(pin));
    
    if (excludeUserId != null) {
      query.where((u) => u.id.equals(excludeUserId).not());
    }
    
    final user = await query.getSingleOrNull();
    return user != null;
  }

  // Get active users count
  Future<int> getActiveUsersCount() async {
    final result = await (_db.selectOnly(_db.users)
          ..addColumns([_db.users.id.count()])
          ..where(_db.users.isActive.equals(true)))
        .getSingle();
    
    return result.read(_db.users.id.count()) ?? 0;
  }

  // === Role-based access control methods ===

  /// Authenticate user by PIN and return user if valid
  /// Returns null if PIN is invalid or user is inactive
  Future<User?> authenticateByPin(String pin) async {
    if (!isValidPin(pin)) return null;
    return getUserByPin(pin);
  }

  /// Check if user has admin role
  Future<bool> isUserAdmin(int userId) async {
    final user = await getUser(userId);
    return user?.role.toLowerCase() == 'admin';
  }

  /// Check if user has manager role
  Future<bool> isUserManager(int userId) async {
    final user = await getUser(userId);
    final role = user?.role.toLowerCase() ?? '';
    return role == 'manager' || role == 'admin';
  }

  /// Get user's role
  Future<String?> getUserRole(int userId) async {
    final user = await getUser(userId);
    return user?.role;
  }

  /// Get all users with a specific role
  Stream<List<User>> watchUsersByRole(String role) {
    return (_db.select(_db.users)
          ..where((u) => u.role.equals(role) & u.isActive.equals(true))
          ..orderBy([(u) => OrderingTerm.asc(u.name)]))
        .watch();
  }

  /// Hash PIN (basic example - use bcrypt or similar in production)
  /// For now, storing as plain text in SQLite; consider hashing in production
  String hashPin(String pin) {
    // TODO: Implement proper password hashing (bcrypt, argon2, etc.)
    // For MVP, we'll use plain text with the understanding this is local storage
    return pin;
  }

  /// Verify PIN against hashed PIN
  bool verifyPin(String pin, String hashedPin) {
    // TODO: Implement proper password verification
    return hashPin(pin) == hashedPin;
  }
}
