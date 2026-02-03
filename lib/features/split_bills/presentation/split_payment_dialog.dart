import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import '../../../core/database/database.dart';
import '../split_bill_repository.dart';

class SplitPaymentDialog extends ConsumerStatefulWidget {
  final SplitBill splitBill;
  final int splitNumber;
  final double amount;

  const SplitPaymentDialog({
    super.key,
    required this.splitBill,
    required this.splitNumber,
    required this.amount,
  });

  @override
  ConsumerState<SplitPaymentDialog> createState() => _SplitPaymentDialogState();
}

class _SplitPaymentDialogState extends ConsumerState<SplitPaymentDialog> {
  String _paymentMethod = 'cash';
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _cashReceivedController = TextEditingController();
  final TextEditingController _referenceController = TextEditingController();
  bool _isProcessing = false;
  double _change = 0.0;

  @override
  void initState() {
    super.initState();
    _amountController.text = widget.amount.toStringAsFixed(2);
    _cashReceivedController.addListener(_calculateChange);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _cashReceivedController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  void _calculateChange() {
    if (_paymentMethod == 'cash') {
      final cashReceived = double.tryParse(_cashReceivedController.text) ?? 0.0;
      final amount = double.tryParse(_amountController.text) ?? 0.0;
      setState(() {
        _change = cashReceived - amount;
      });
    } else {
      setState(() {
        _change = 0.0;
      });
    }
  }

  Future<void> _processPayment() async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    if (_paymentMethod == 'cash') {
      final cashReceived = double.tryParse(_cashReceivedController.text) ?? 0.0;
      if (cashReceived < amount) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cash received must be at least the amount due')),
        );
        return;
      }
    }

    setState(() => _isProcessing = true);

    try {
      final repository = ref.read(splitBillRepositoryProvider);

      // Record payment
      await repository.recordPayment(
        SplitBillPaymentsCompanion(
          splitBillId: drift.Value(widget.splitBill.id),
          splitNumber: drift.Value(widget.splitNumber),
          amount: drift.Value(amount),
          cashReceived: drift.Value(
            _paymentMethod == 'cash'
                ? double.parse(_cashReceivedController.text)
                : amount,
          ),
          change: drift.Value(_change),
          paymentMethod: drift.Value(_paymentMethod),
          transactionReference: drift.Value(_referenceController.text.isNotEmpty
              ? _referenceController.text
              : null),
          paidAt: drift.Value(DateTime.now()),
        ),
      );

      // Mark split as paid
      await repository.markSplitPaid(widget.splitBill.id, widget.splitNumber);

      // Check if all splits are paid
      final allPaid = await repository.areAllSplitsPaid(widget.splitBill.id);
      if (allPaid) {
        await repository.completeSplitBill(widget.splitBill.id);
      }

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment recorded successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error processing payment: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.payment, size: 28),
                const SizedBox(width: 12),
                Text(
                  'Payment - Split ${widget.splitNumber}',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildAmountDisplay(),
            const SizedBox(height: 24),
            _buildPaymentMethodSelector(),
            const SizedBox(height: 16),
            if (_paymentMethod == 'cash') ...[
              _buildCashReceivedField(),
              const SizedBox(height: 16),
              _buildChangeDisplay(),
            ] else ...[
              _buildReferenceField(),
            ],
            const SizedBox(height: 24),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountDisplay() {
    return Card(
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Text(
              'Amount Due:',
              style: TextStyle(fontSize: 16),
            ),
            const Spacer(),
            Text(
              'RM ${widget.amount.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Payment Method', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(
              value: 'cash',
              label: Text('Cash'),
              icon: Icon(Icons.payments),
            ),
            ButtonSegment(
              value: 'card',
              label: Text('Card'),
              icon: Icon(Icons.credit_card),
            ),
            ButtonSegment(
              value: 'gcash',
              label: Text('GCash'),
              icon: Icon(Icons.account_balance_wallet),
            ),
          ],
          selected: {_paymentMethod},
          onSelectionChanged: (Set<String> selected) {
            setState(() {
              _paymentMethod = selected.first;
              _calculateChange();
            });
          },
        ),
      ],
    );
  }

  Widget _buildCashReceivedField() {
    return TextFormField(
      controller: _cashReceivedController,
      keyboardType: TextInputType.number,
      autofocus: true,
      decoration: const InputDecoration(
        labelText: 'Cash Received',
        prefixText: 'RM',
        border: OutlineInputBorder(),
      ),
    );
  }

  Widget _buildChangeDisplay() {
    return Card(
      color: _change >= 0 ? Colors.blue.shade50 : Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Text(
              _change >= 0 ? 'Change:' : 'Short:',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            Text(
              'RM ${_change.abs().toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: _change >= 0 ? Colors.blue : Colors.red,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReferenceField() {
    return TextFormField(
      controller: _referenceController,
      decoration: InputDecoration(
        labelText: 'Transaction Reference',
        hintText: _paymentMethod == 'card'
            ? 'Last 4 digits / Auth Code'
            : 'Reference Number',
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: _isProcessing ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          onPressed: _isProcessing ? null : _processPayment,
          icon: _isProcessing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check),
          label: Text(_isProcessing ? 'Processing...' : 'Complete Payment'),
        ),
      ],
    );
  }
}
