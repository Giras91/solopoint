import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import '../../../core/database/database.dart';
import '../split_bill_repository.dart';

class SplitBillDialog extends ConsumerStatefulWidget {
  final Order order;
  final List<OrderItem> orderItems;

  const SplitBillDialog({
    super.key,
    required this.order,
    required this.orderItems,
  });

  @override
  ConsumerState<SplitBillDialog> createState() => _SplitBillDialogState();
}

class _SplitBillDialogState extends ConsumerState<SplitBillDialog> {
  String _splitType = 'by_people'; // by_people, by_items, by_amount
  int _splitCount = 2;
  final List<List<OrderItem>> _itemsPerSplit = [];
  final List<double> _amountsPerSplit = [];
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _initializeSplit();
  }

  void _initializeSplit() {
    if (_splitType == 'by_people') {
      // Equal split
      _amountsPerSplit.clear();
      final amountPerPerson = widget.order.total / _splitCount;
      for (int i = 0; i < _splitCount; i++) {
        _amountsPerSplit.add(amountPerPerson);
      }
    } else if (_splitType == 'by_items') {
      // Initialize empty lists for item allocation
      _itemsPerSplit.clear();
      for (int i = 0; i < _splitCount; i++) {
        _itemsPerSplit.add([]);
      }
    } else {
      // Custom amounts
      _amountsPerSplit.clear();
      for (int i = 0; i < _splitCount; i++) {
        _amountsPerSplit.add(0.0);
      }
    }
  }

  Future<void> _createSplitBill() async {
    setState(() => _isProcessing = true);

    try {
      final splitBillRepo = ref.read(splitBillRepositoryProvider);

      // Create split bill record
      final splitBillId = await splitBillRepo.createSplitBill(
        SplitBillsCompanion(
          orderId: drift.Value(widget.order.id),
          splitType: drift.Value(_splitType),
          splitCount: drift.Value(_splitCount),
          originalTotal: drift.Value(widget.order.total),
          status: const drift.Value('pending'),
        ),
      );

      // Create split bill items
      if (_splitType == 'by_people') {
        // Equal split - distribute all items equally
        for (int i = 0; i < _splitCount; i++) {
          await splitBillRepo.addSplitBillItem(
            SplitBillItemsCompanion(
              splitBillId: drift.Value(splitBillId),
              splitNumber: drift.Value(i + 1),
              orderItemId: const drift.Value(null), // All items
              amount: drift.Value(_amountsPerSplit[i]),
              paidAmount: const drift.Value(0.0),
              isPaid: const drift.Value(false),
            ),
          );
        }
      } else if (_splitType == 'by_items') {
        // By items - assign specific items to each split
        for (int i = 0; i < _splitCount; i++) {
          for (final item in _itemsPerSplit[i]) {
            await splitBillRepo.addSplitBillItem(
              SplitBillItemsCompanion(
                splitBillId: drift.Value(splitBillId),
                splitNumber: drift.Value(i + 1),
                orderItemId: drift.Value(item.id),
                amount: drift.Value(item.total),
                paidAmount: const drift.Value(0.0),
                isPaid: const drift.Value(false),
              ),
            );
          }
        }
      } else {
        // Custom amounts
        for (int i = 0; i < _splitCount; i++) {
          await splitBillRepo.addSplitBillItem(
            SplitBillItemsCompanion(
              splitBillId: drift.Value(splitBillId),
              splitNumber: drift.Value(i + 1),
              orderItemId: const drift.Value(null),
              amount: drift.Value(_amountsPerSplit[i]),
              paidAmount: const drift.Value(0.0),
              isPaid: const drift.Value(false),
            ),
          );
        }
      }

      if (mounted) {
        Navigator.of(context).pop(splitBillId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bill split created successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating split: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  bool _canCreateSplit() {
    if (_splitType == 'by_amount') {
      final total = _amountsPerSplit.fold<double>(0.0, (sum, amt) => sum + amt);
      return (total - widget.order.total).abs() < 0.01; // Allow 1 centavo tolerance
    }
    if (_splitType == 'by_items') {
      // Check if all items are allocated
      final allocatedItems = _itemsPerSplit.expand((list) => list).toSet();
      return allocatedItems.length == widget.orderItems.length;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 700),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.call_split, size: 28),
                const SizedBox(width: 12),
                Text(
                  'Split Bill',
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
            _buildOrderSummary(),
            const Divider(height: 32),
            _buildSplitTypeSelector(),
            const SizedBox(height: 16),
            _buildSplitCountSelector(),
            const SizedBox(height: 24),
            Expanded(child: _buildSplitDetails()),
            const SizedBox(height: 24),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderSummary() {
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Order #${widget.order.id}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text('${widget.orderItems.length} items'),
                ],
              ),
            ),
            Text(
              'RM ${widget.order.total.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSplitTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Split Type', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'by_people', label: Text('Equal'), icon: Icon(Icons.people)),
            ButtonSegment(value: 'by_items', label: Text('By Items'), icon: Icon(Icons.list)),
            ButtonSegment(value: 'by_amount', label: Text('Custom'), icon: Icon(Icons.payments)),
          ],
          selected: {_splitType},
          onSelectionChanged: (Set<String> selected) {
            setState(() {
              _splitType = selected.first;
              _initializeSplit();
            });
          },
        ),
      ],
    );
  }

  Widget _buildSplitCountSelector() {
    return Row(
      children: [
        const Text('Number of Splits:', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(width: 16),
        IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: _splitCount > 2
              ? () => setState(() {
                    _splitCount--;
                    _initializeSplit();
                  })
              : null,
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$_splitCount',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          onPressed: _splitCount < 10
              ? () => setState(() {
                    _splitCount++;
                    _initializeSplit();
                  })
              : null,
        ),
      ],
    );
  }

  Widget _buildSplitDetails() {
    if (_splitType == 'by_people') {
      return _buildEqualSplitView();
    } else if (_splitType == 'by_items') {
      return _buildItemSplitView();
    } else {
      return _buildCustomAmountView();
    }
  }

  Widget _buildEqualSplitView() {
    return ListView.builder(
      itemCount: _splitCount,
      itemBuilder: (context, index) {
        return Card(
          child: ListTile(
            leading: CircleAvatar(child: Text('${index + 1}')),
            title: Text('Split ${index + 1}'),
            trailing: Text(
              '₱${_amountsPerSplit[index].toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        );
      },
    );
  }

  Widget _buildItemSplitView() {
    return Column(
      children: [
        Text(
          'Drag items to assign them to splits',
          style: TextStyle(color: Colors.grey.shade600),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Row(
            children: [
              // Unassigned items
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Items', style: TextStyle(fontWeight: FontWeight.bold)),
                    Expanded(
                      child: ListView.builder(
                        itemCount: widget.orderItems.length,
                        itemBuilder: (context, index) {
                          final item = widget.orderItems[index];
                          final isAssigned = _itemsPerSplit
                              .any((list) => list.any((i) => i.id == item.id));
                          
                          if (isAssigned) return const SizedBox.shrink();

                          return Card(
                            child: ListTile(
                              dense: true,
                              title: Text(item.productName),
                              subtitle: Text('${item.quantity}x ₱${item.unitPrice.toStringAsFixed(2)}'),
                              trailing: Text('₱${item.total.toStringAsFixed(2)}'),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Splits
              Expanded(
                flex: 2,
                child: ListView.builder(
                  itemCount: _splitCount,
                  itemBuilder: (context, splitIndex) {
                    final splitItems = _itemsPerSplit[splitIndex];
                    final splitTotal = splitItems.fold<double>(
                      0.0,
                      (sum, item) => sum + item.total,
                    );

                    return Card(
                      color: Colors.grey.shade100,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 12,
                                  child: Text('${splitIndex + 1}', style: const TextStyle(fontSize: 12)),
                                ),
                                const SizedBox(width: 8),
                                Text('Split ${splitIndex + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                const Spacer(),
                                Text('₱${splitTotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            ),
                            if (splitItems.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(8),
                                child: Text('No items', style: TextStyle(color: Colors.grey)),
                              )
                            else
                              ...splitItems.map((item) => ListTile(
                                    dense: true,
                                    title: Text(item.productName, style: const TextStyle(fontSize: 12)),
                                    trailing: Text('₱${item.total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12)),
                                  )),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCustomAmountView() {
    final remainingAmount = widget.order.total -
        _amountsPerSplit.fold<double>(0.0, (sum, amt) => sum + amt);

    return Column(
      children: [
        if (remainingAmount.abs() > 0.01)
          Card(
            color: Colors.orange.shade50,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber, color: Colors.orange),
                  const SizedBox(width: 8),
                  Text(
                    'Remaining: ₱${remainingAmount.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        Expanded(
          child: ListView.builder(
            itemCount: _splitCount,
            itemBuilder: (context, index) {
              return Card(
                child: ListTile(
                  leading: CircleAvatar(child: Text('${index + 1}')),
                  title: Text('Split ${index + 1}'),
                  trailing: SizedBox(
                    width: 150,
                    child: TextFormField(
                      initialValue: _amountsPerSplit[index].toStringAsFixed(2),
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        prefixText: '₱',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _amountsPerSplit[index] = double.tryParse(value) ?? 0.0;
                        });
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
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
          onPressed: (_isProcessing || !_canCreateSplit())
              ? null
              : _createSplitBill,
          icon: _isProcessing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check),
          label: Text(_isProcessing ? 'Creating...' : 'Create Split'),
        ),
      ],
    );
  }
}
