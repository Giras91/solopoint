import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'kds_repository.dart';

final kitchenStatusFilterProvider = StateProvider<KitchenStatusFilter>((ref) {
  return KitchenStatusFilter.all;
});

final kitchenOrdersProvider = StreamProvider<List<KitchenOrder>>((ref) {
  final repository = ref.watch(kdsRepositoryProvider);
  return repository.watchKitchenOrders();
});

enum KitchenStatusFilter { all, pending, inProgress, ready }
