import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/database.dart';
import 'split_bill_repository.dart';

// Split bill by order provider
final splitBillByOrderProvider = FutureProvider.family<SplitBill?, int>(
  (ref, orderId) {
    final repository = ref.watch(splitBillRepositoryProvider);
    return repository.getSplitBillByOrderId(orderId);
  },
);

// Split bill items provider
final splitBillItemsProvider = StreamProvider.family<List<SplitBillItem>, int>(
  (ref, splitBillId) {
    final repository = ref.watch(splitBillRepositoryProvider);
    return repository.watchSplitBillItems(splitBillId);
  },
);

// Active split bill provider
final activeSplitBillProvider = StateProvider<SplitBill?>((ref) => null);
