import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database.dart';
import '../split_bill_repository.dart';
import 'split_payment_dialog.dart';

class SplitBillManagementScreen extends ConsumerStatefulWidget {
  final int splitBillId;

  const SplitBillManagementScreen({
    super.key,
    required this.splitBillId,
  });

  @override
  ConsumerState<SplitBillManagementScreen> createState() =>
      _SplitBillManagementScreenState();
}

class _SplitBillManagementScreenState
    extends ConsumerState<SplitBillManagementScreen> {
  SplitBill? _splitBill;
  List<SplitBillItem> _items = [];
  Map<int, double> _splitTotals = {};
  Map<int, double> _paidAmounts = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSplitBill();
  }

  Future<void> _loadSplitBill() async {
    setState(() => _isLoading = true);

    try {
      final repository = ref.read(splitBillRepositoryProvider);

      // Load split bill
      final splitBill = await repository.watchSplitBill(widget.splitBillId).first;
      if (splitBill == null) {
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Split bill not found')),
          );
        }
        return;
      }

      // Load items
      final items = await repository.getSplitBillItems(widget.splitBillId);

      // Calculate totals and paid amounts
      final splitTotals = await repository.getSplitSummary(widget.splitBillId);
      final paidAmounts = await repository.getPaidAmountPerSplit(widget.splitBillId);

      setState(() {
        _splitBill = splitBill;
        _items = items;
        _splitTotals = splitTotals;
        _paidAmounts = paidAmounts;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading split bill: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _processSplitPayment(int splitNumber, double amount) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => SplitPaymentDialog(
        splitBill: _splitBill!,
        splitNumber: splitNumber,
        amount: amount,
      ),
    );

    if (result == true) {
      _loadSplitBill(); // Reload to get updated payment status
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Split Bill')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_splitBill == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Split Bill')),
        body: const Center(child: Text('Split bill not found')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Split Bill Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSplitBill,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildHeader(),
          const Divider(),
          Expanded(child: _buildSplitsList()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final allPaid = _items.every((item) => item.isPaid);
    
    return Container(
      padding: const EdgeInsets.all(16),
      color: allPaid ? Colors.green.shade50 : Colors.blue.shade50,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order #${_splitBill!.orderId}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Split Type: ${_getSplitTypeLabel(_splitBill!.splitType)}',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    Text(
                      '${_splitBill!.splitCount} splits',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'RM ${_splitBill!.originalTotal.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: allPaid ? Colors.green : Colors.orange,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      allPaid ? 'COMPLETED' : _splitBill!.status.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSplitsList() {
    final splitNumbers = _splitTotals.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: splitNumbers.length,
      itemBuilder: (context, index) {
        final splitNumber = splitNumbers[index];
        final splitTotal = _splitTotals[splitNumber] ?? 0.0;
        final paidAmount = _paidAmounts[splitNumber] ?? 0.0;
        final remainingAmount = splitTotal - paidAmount;
        final isPaid = remainingAmount <= 0.01; // Allow 1 centavo tolerance

        final splitItems = _items
            .where((item) => item.splitNumber == splitNumber)
            .toList();

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: isPaid ? 1 : 3,
          child: Column(
            children: [
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: isPaid ? Colors.green : Colors.blue,
                  child: Text(
                    '$splitNumber',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  'Split $splitNumber',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  isPaid
                      ? 'Paid'
                      : 'Remaining: RM ${remainingAmount.toStringAsFixed(2)}',
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'RM ${splitTotal.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (paidAmount > 0)
                      Text(
                        'Paid: RM ${paidAmount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                  ],
                ),
              ),
              if (!isPaid)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: ElevatedButton.icon(
                    onPressed: () => _processSplitPayment(splitNumber, remainingAmount),
                    icon: const Icon(Icons.payment),
                    label: const Text('Process Payment'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                ),
              if (splitItems.isNotEmpty && _splitBill!.splitType == 'by_items')
                ExpansionTile(
                  title: const Text('Items', style: TextStyle(fontSize: 14)),
                  children: splitItems
                      .map((item) => ListTile(
                            dense: true,
                            title: Text('Item #${item.orderItemId ?? "All"}'),
                            trailing: Text('RM ${item.amount.toStringAsFixed(2)}'),
                          ))
                      .toList(),
                ),
            ],
          ),
        );
      },
    );
  }

  String _getSplitTypeLabel(String type) {
    switch (type) {
      case 'by_people':
        return 'Equal Split';
      case 'by_items':
        return 'By Items';
      case 'by_amount':
        return 'Custom Amount';
      default:
        return type;
    }
  }
}
