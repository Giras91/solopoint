import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/database.dart';

final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return CustomerRepository(db);
});

class CustomerRepository {
  final AppDatabase _db;

  CustomerRepository(this._db);

  // Create new customer
  Future<int> createCustomer(CustomersCompanion customer) {
    return _db.into(_db.customers).insert(customer);
  }

  // Get all customers
  Future<List<Customer>> getAllCustomers() {
    return _db.select(_db.customers).get();
  }

  // Watch all customers (Stream)
  Stream<List<Customer>> watchAllCustomers() {
    return _db.select(_db.customers).watch();
  }

  // Get customer by ID
  Future<Customer?> getCustomerById(int id) {
    return (_db.select(_db.customers)..where((c) => c.id.equals(id))).getSingleOrNull();
  }

  // Search customers by name or phone
  Stream<List<Customer>> searchCustomers(String query) {
    return (_db.select(_db.customers)
      ..where((c) =>
          c.name.like('%$query%') | c.phone.like('%$query%')))
      .watch();
  }

  // Update customer
  Future<bool> updateCustomer(Customer customer) {
    return _db.update(_db.customers).replace(customer);
  }

  // Delete customer
  Future<int> deleteCustomer(int id) {
    return (_db.delete(_db.customers)..where((c) => c.id.equals(id))).go();
  }

  // Add loyalty points to customer
  Future<void> addLoyaltyPoints(int customerId, int points) async {
    final customer = await getCustomerById(customerId);
    if (customer != null) {
      await _db.update(_db.customers).replace(
        customer.copyWith(loyaltyPoints: customer.loyaltyPoints + points),
      );
    }
  }

  // Update total spent for customer
  Future<void> updateTotalSpent(int customerId, double amount) async {
    final customer = await getCustomerById(customerId);
    if (customer != null) {
      await _db.update(_db.customers).replace(
        customer.copyWith(totalSpent: customer.totalSpent + amount),
      );
    }
  }
}
