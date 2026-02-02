import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/database/database.dart';
import '../../../customers/customer_providers.dart';

class CheckoutDialog extends ConsumerStatefulWidget {
  final double totalAmount;
  final Function(double cashReceived, String paymentMethod, int? customerId) onConfirm;

  const CheckoutDialog({
    super.key,
    required this.totalAmount,
    required this.onConfirm,
  });

  @override
  ConsumerState<CheckoutDialog> createState() => _CheckoutDialogState();
}

class _CheckoutDialogState extends ConsumerState<CheckoutDialog> {
  final _cashController = TextEditingController();
  String _selectedMethod = 'cash'; // 'cash', 'card', 'qr'
  double _change = 0.0;
  Customer? _selectedCustomer;

  @override
  void initState() {
    super.initState();
    _cashController.addListener(_calculateChange);
  }

  @override
  void dispose() {
    _cashController.dispose();
    super.dispose();
  }

  void _calculateChange() {
    final cash = double.tryParse(_cashController.text) ?? 0.0;
    setState(() {
      _change = cash - widget.totalAmount;
    });
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customerListProvider);

    return AlertDialog(
      title: const Text('Checkout'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Total Display
            Text(
              'Total: ${CurrencyFormatter.format(widget.totalAmount)}',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // Customer Selection
            customersAsync.when(
              data: (customers) {
                return DropdownButtonFormField<Customer?>(
                  initialValue: _selectedCustomer,
                  decoration: const InputDecoration(
                    labelText: 'Customer (Optional)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  items: [
                    const DropdownMenuItem<Customer?>(
                      value: null,
                      child: Text('Walk-in Customer'),
                    ),
                    ...customers.map((customer) {
                      return DropdownMenuItem<Customer?>(
                        value: customer,
                        child: Text('${customer.name} (${customer.loyaltyPoints} pts)'),
                      );
                    }),
                  ],
                  onChanged: (customer) {
                    setState(() => _selectedCustomer = customer);
                  },
                );
              },
              loading: () => const SizedBox(height: 60),
              error: (_, __) => const SizedBox(height: 60),
            ),
            const SizedBox(height: 20),

            // Payment Methods
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'cash', label: Text('Cash'), icon: Icon(Icons.money)),
                ButtonSegment(value: 'card', label: Text('Card'), icon: Icon(Icons.credit_card)),
                ButtonSegment(value: 'qr', label: Text('QR'), icon: Icon(Icons.qr_code)),
              ],
              selected: {_selectedMethod},
              onSelectionChanged: (newSelection) {
                setState(() {
                  _selectedMethod = newSelection.first;
                  if (_selectedMethod != 'cash') {
                    _cashController.text = widget.totalAmount.toString(); // Auto-fill
                  } else {
                    _cashController.clear();
                  }
                });
              },
            ),
            const SizedBox(height: 20),

            // Cash Input
            TextField(
              controller: _cashController,
              decoration: const InputDecoration(
                labelText: 'Amount Received',
                border: OutlineInputBorder(),
                prefixText: '₱ ',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
            ),
            const SizedBox(height: 20),

            // Change Display
            if (_selectedMethod == 'cash')
              Container(
                padding: const EdgeInsets.all(16),
                color: _change >= 0 ? Colors.green.shade50 : Colors.red.shade50,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Change:',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      CurrencyFormatter.format(_change >= 0 ? _change : 0),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: _change >= 0 ? Colors.green : Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
              ),
            
            // Customer Info Display
            if (_selectedCustomer != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🎁 Loyalty Reward',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '+${_calculateLoyaltyPoints()} points will be earned!',
                      style: TextStyle(color: Colors.orange.shade800),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: (_change >= 0 || _selectedMethod != 'cash')
              ? () {
                  final cash = double.tryParse(_cashController.text) ?? 0.0;
                  widget.onConfirm(cash, _selectedMethod, _selectedCustomer?.id);
                  Navigator.of(context).pop();
                }
              : null, // Disable if insufficient cash
          child: const Text('Complete Order'),
        ),
      ],
    );
  }

  int _calculateLoyaltyPoints() {
    // 1 point per ₱10 spent (adjust as needed)
    return (widget.totalAmount / 10).floor();
  }
}
