import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import 'dart:convert';
import '../../core/database/database.dart';

final roleRepositoryProvider = Provider<RoleRepository>((ref) {
  final database = ref.watch(databaseProvider);
  return RoleRepository(database);
});

class RoleRepository {
  final AppDatabase _db;

  RoleRepository(this._db);

  /// Watch all roles
  Stream<List<Role>> watchAllRoles() {
    return (_db.select(_db.roles)
          ..orderBy([(r) => OrderingTerm.asc(r.name)]))
        .watch();
  }

  /// Watch all active roles
  Stream<List<Role>> watchActiveRoles() {
    return (_db.select(_db.roles)
          ..where((r) => r.isActive.equals(true))
          ..orderBy([(r) => OrderingTerm.asc(r.name)]))
        .watch();
  }

  /// Get single role by ID
  Future<Role?> getRole(int id) {
    return (_db.select(_db.roles)..where((r) => r.id.equals(id)))
        .getSingleOrNull();
  }

  /// Get role by name
  Future<Role?> getRoleByName(String name) {
    return (_db.select(_db.roles)..where((r) => r.name.equals(name)))
        .getSingleOrNull();
  }

  /// Create new role
  Future<int> createRole(RolesCompanion role) {
    return _db.into(_db.roles).insert(role);
  }

  /// Create default roles if they don't exist
  Future<void> createDefaultRoles() async {
    final adminRole = await getRoleByName('admin');
    if (adminRole == null) {
      await createRole(
        RolesCompanion(
          name: const Value('admin'),
          description: const Value('Administrator with full system access'),
          permissions: Value(
            jsonEncode({
              'view_reports': true,
              'manage_inventory': true,
              'manage_staff': true,
              'void_orders': true,
              'open_drawer': true,
              'edit_prices': true,
              'view_financials': true,
              'access_audit_log': true,
              'manage_roles': true,
            }),
          ),
          isActive: const Value(true),
        ),
      );
    }

    final managerRole = await getRoleByName('manager');
    if (managerRole == null) {
      await createRole(
        RolesCompanion(
          name: const Value('manager'),
          description: const Value('Manager with limited access to reports and inventory'),
          permissions: Value(
            jsonEncode({
              'view_reports': true,
              'manage_inventory': true,
              'manage_staff': false,
              'void_orders': true,
              'open_drawer': true,
              'edit_prices': false,
              'view_financials': true,
              'access_audit_log': true,
              'manage_roles': false,
            }),
          ),
          isActive: const Value(true),
        ),
      );
    }

    final cashierRole = await getRoleByName('cashier');
    if (cashierRole == null) {
      await createRole(
        RolesCompanion(
          name: const Value('cashier'),
          description: const Value('Cashier with basic POS access'),
          permissions: Value(
            jsonEncode({
              'view_reports': false,
              'manage_inventory': false,
              'manage_staff': false,
              'void_orders': false,
              'open_drawer': false,
              'edit_prices': false,
              'view_financials': false,
              'access_audit_log': false,
              'manage_roles': false,
            }),
          ),
          isActive: const Value(true),
        ),
      );
    }

    final staffRole = await getRoleByName('staff');
    if (staffRole == null) {
      await createRole(
        RolesCompanion(
          name: const Value('staff'),
          description: const Value('Staff with minimal access'),
          permissions: Value(
            jsonEncode({
              'view_reports': false,
              'manage_inventory': false,
              'manage_staff': false,
              'void_orders': false,
              'open_drawer': false,
              'edit_prices': false,
              'view_financials': false,
              'access_audit_log': false,
              'manage_roles': false,
            }),
          ),
          isActive: const Value(true),
        ),
      );
    }
  }

  /// Update role
  Future<int> updateRole(int id, RolesCompanion role) {
    return (_db.update(_db.roles)..where((r) => r.id.equals(id))).write(role);
  }

  /// Delete role
  Future<int> deleteRole(int id) {
    return (_db.delete(_db.roles)..where((r) => r.id.equals(id))).go();
  }

  /// Toggle role active status
  Future<int> toggleRoleStatus(int id, bool isActive) {
    return (_db.update(_db.roles)..where((r) => r.id.equals(id)))
        .write(RolesCompanion(isActive: Value(isActive)));
  }

  /// === Permission management ===

  /// Parse permissions JSON string to Map
  Map<String, dynamic> parsePermissions(String permissionsJson) {
    try {
      return jsonDecode(permissionsJson) as Map<String, dynamic>;
    } catch (e) {
      return {};
    }
  }

  /// Convert permissions Map to JSON string
  String encodePermissions(Map<String, dynamic> permissions) {
    return jsonEncode(permissions);
  }

  /// Check if role has specific permission
  Future<bool> hasPermission(int roleId, String permissionKey) async {
    final role = await getRole(roleId);
    if (role == null) return false;

    final permissions = parsePermissions(role.permissions);
    return permissions[permissionKey] == true;
  }

  /// Check if user (via role) has specific permission
  Future<bool> userHasPermission(int userId, String permissionKey) async {
    // This method should be called from UserRepository with the user's role
    // Placeholder implementation
    return false;
  }

  /// Get all permissions for a role
  Future<Map<String, dynamic>> getRolePermissions(int roleId) async {
    final role = await getRole(roleId);
    if (role == null) return {};
    return parsePermissions(role.permissions);
  }

  /// Update specific permission for a role
  Future<int> updateRolePermission(
    int roleId,
    String permissionKey,
    bool value,
  ) async {
    final role = await getRole(roleId);
    if (role == null) return 0;

    final permissions = parsePermissions(role.permissions);
    permissions[permissionKey] = value;

    return updateRole(
      roleId,
      RolesCompanion(
        permissions: Value(encodePermissions(permissions)),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Bulk update permissions for a role
  Future<int> updateRolePermissions(
    int roleId,
    Map<String, bool> permissionsUpdate,
  ) async {
    final role = await getRole(roleId);
    if (role == null) return 0;

    final currentPermissions = parsePermissions(role.permissions);
    currentPermissions.addAll(permissionsUpdate);

    return updateRole(
      roleId,
      RolesCompanion(
        permissions: Value(encodePermissions(currentPermissions)),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}
