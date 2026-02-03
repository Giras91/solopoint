import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/database.dart';

final splitBillRepositoryProvider = Provider<SplitBillRepository>((ref) {
  final database = ref.watch(databaseProvider);
  return SplitBillRepository(database);
});

class SplitBillRepository {
  final AppDatabase _database;

  SplitBillRepository(this._database);

  // Create split bill
  Future<int> createSplitBill(SplitBillsCompanion splitBill) {
    return _database.into(_database.splitBills).insert(splitBill);
  }

  // Get split bill by order ID
  Future<SplitBill?> getSplitBillByOrderId(int orderId) {
    return (_database.select(_database.splitBills)
          ..where((tbl) => tbl.orderId.equals(orderId)))
        .getSingleOrNull();
  }

  // Watch split bill by ID
  Stream<SplitBill?> watchSplitBill(int splitBillId) {
    return (_database.select(_database.splitBills)
          ..where((tbl) => tbl.id.equals(splitBillId)))
        .watchSingleOrNull();
  }

  // Get split bill items
  Future<List<SplitBillItem>> getSplitBillItems(int splitBillId) {
    return (_database.select(_database.splitBillItems)
          ..where((tbl) => tbl.splitBillId.equals(splitBillId)))
        .get();
  }

  // Watch split bill items
  Stream<List<SplitBillItem>> watchSplitBillItems(int splitBillId) {
    return (_database.select(_database.splitBillItems)
          ..where((tbl) => tbl.splitBillId.equals(splitBillId)))
        .watch();
  }

  // Get items for specific split number
  Future<List<SplitBillItem>> getSplitItems(int splitBillId, int splitNumber) {
    return (_database.select(_database.splitBillItems)
          ..where((tbl) =>
              tbl.splitBillId.equals(splitBillId) &
              tbl.splitNumber.equals(splitNumber)))
        .get();
  }

  // Add split bill item
  Future<int> addSplitBillItem(SplitBillItemsCompanion item) {
    return _database.into(_database.splitBillItems).insert(item);
  }

  // Mark split as paid
  Future<void> markSplitPaid(int splitBillId, int splitNumber) {
    return (_database.update(_database.splitBillItems)
          ..where((tbl) =>
              tbl.splitBillId.equals(splitBillId) &
              tbl.splitNumber.equals(splitNumber)))
        .write(SplitBillItemsCompanion(
      isPaid: const Value(true),
      paidAt: Value(DateTime.now()),
    ));
  }

  // Record split payment
  Future<int> recordPayment(SplitBillPaymentsCompanion payment) {
    return _database.into(_database.splitBillPayments).insert(payment);
  }

  // Get payments for split
  Future<List<SplitBillPayment>> getSplitPayments(int splitBillId, int splitNumber) {
    return (_database.select(_database.splitBillPayments)
          ..where((tbl) =>
              tbl.splitBillId.equals(splitBillId) &
              tbl.splitNumber.equals(splitNumber)))
        .get();
  }

  // Get all payments for split bill
  Future<List<SplitBillPayment>> getAllPayments(int splitBillId) {
    return (_database.select(_database.splitBillPayments)
          ..where((tbl) => tbl.splitBillId.equals(splitBillId)))
        .get();
  }

  // Update split bill status
  Future<void> updateSplitBillStatus(int splitBillId, String status) {
    return (_database.update(_database.splitBills)
          ..where((tbl) => tbl.id.equals(splitBillId)))
        .write(SplitBillsCompanion(status: Value(status)));
  }

  // Complete split bill
  Future<void> completeSplitBill(int splitBillId) {
    return (_database.update(_database.splitBills)
          ..where((tbl) => tbl.id.equals(splitBillId)))
        .write(SplitBillsCompanion(
      status: const Value('completed'),
      completedAt: Value(DateTime.now()),
    ));
  }

  // Check if all splits are paid
  Future<bool> areAllSplitsPaid(int splitBillId) async {
    final items = await getSplitBillItems(splitBillId);
    return items.every((item) => item.isPaid);
  }

  // Get split summary
  Future<Map<int, double>> getSplitSummary(int splitBillId) async {
    final items = await getSplitBillItems(splitBillId);
    final summary = <int, double>{};
    
    for (final item in items) {
      summary[item.splitNumber] = (summary[item.splitNumber] ?? 0.0) + item.amount;
    }
    
    return summary;
  }

  // Get paid amount per split
  Future<Map<int, double>> getPaidAmountPerSplit(int splitBillId) async {
    final payments = await getAllPayments(splitBillId);
    final paidAmounts = <int, double>{};
    
    for (final payment in payments) {
      paidAmounts[payment.splitNumber] = 
          (paidAmounts[payment.splitNumber] ?? 0.0) + payment.amount;
    }
    
    return paidAmounts;
  }
}
