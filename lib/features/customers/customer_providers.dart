import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/database.dart';
import 'customer_repository.dart';

// Stream of all customers
final customerListProvider = StreamProvider<List<Customer>>((ref) {
  final repository = ref.watch(customerRepositoryProvider);
  return repository.watchAllCustomers();
});

// Search provider with query
final customerSearchQueryProvider = StateProvider<String>((ref) => '');

// Filtered customers based on search
final filteredCustomersProvider = StreamProvider<List<Customer>>((ref) {
  final repository = ref.watch(customerRepositoryProvider);
  final query = ref.watch(customerSearchQueryProvider);
  
  if (query.isEmpty) {
    return repository.watchAllCustomers();
  }
  
  return repository.searchCustomers(query);
});
