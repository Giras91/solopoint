import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/currency_formatter.dart';
import '../forecasting_providers.dart';
import '../forecasting_repository.dart';

class ForecastingScreen extends ConsumerStatefulWidget {
  const ForecastingScreen({super.key});

  @override
  ConsumerState<ForecastingScreen> createState() => _ForecastingScreenState();
}

class _ForecastingScreenState extends ConsumerState<ForecastingScreen> {
  late TextEditingController _leadTimeController;
  late TextEditingController _safetyStockController;

  @override
  void initState() {
    super.initState();
    _leadTimeController = TextEditingController();
    _safetyStockController = TextEditingController();
  }

  @override
  void dispose() {
    _leadTimeController.dispose();
    _safetyStockController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final range = ref.watch(forecastDateRangeProvider);
    final leadTime = ref.watch(leadTimeDaysProvider);
    final safetyStock = ref.watch(safetyStockDaysProvider);

    _leadTimeController.text = leadTime.toString();
    _safetyStockController.text = safetyStock.toString();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory Forecasting'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () => _pickDateRange(context, range),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(forecastItemsProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildRangeCard(range),
              const SizedBox(height: 16),
              _buildSettingsCard(),
              const SizedBox(height: 16),
              _buildSummaryHint(),
              const SizedBox(height: 16),
              _buildForecastList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRangeCard(DateTimeRange range) {
    final formatter = DateFormat('MMM dd, yyyy');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.date_range),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${formatter.format(range.start)} - ${formatter.format(range.end)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            TextButton.icon(
              onPressed: () => _pickDateRange(context, range),
              icon: const Icon(Icons.edit),
              label: const Text('Change'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Forecast Settings',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _leadTimeController,
                    decoration: const InputDecoration(
                      labelText: 'Lead time (days)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _safetyStockController,
                    decoration: const InputDecoration(
                      labelText: 'Safety stock (days)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: _applySettings,
                icon: const Icon(Icons.check),
                label: const Text('Apply'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryHint() {
    return const Text(
      'Suggested reorder = forecast demand (lead time + safety stock) minus current stock.',
      style: TextStyle(color: Colors.grey),
    );
  }

  Widget _buildForecastList() {
    final itemsAsync = ref.watch(forecastItemsProvider);

    return itemsAsync.when(
      data: (items) {
        if (items.isEmpty) {
          return const Center(child: Text('No products available.'));
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final item = items[index];
            return ListTile(
              title: Text(item.productName),
              subtitle: Text(
                'Stock: ${item.currentStock.toStringAsFixed(1)}  •  Avg/day: ${item.avgDailySales.toStringAsFixed(2)}',
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Reorder: ${item.suggestedReorder.toStringAsFixed(1)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _statusColor(item.status),
                    ),
                  ),
                  Text(
                    _statusLabel(item.status),
                    style: TextStyle(fontSize: 11, color: _statusColor(item.status)),
                  ),
                ],
              ),
              onTap: () => _showDetailSheet(context, item),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, st) => Center(child: Text('Error: $err')),
    );
  }

  void _applySettings() {
    final leadTime = int.tryParse(_leadTimeController.text) ?? 7;
    final safetyStock = int.tryParse(_safetyStockController.text) ?? 3;

    ref.read(leadTimeDaysProvider.notifier).state = leadTime;
    ref.read(safetyStockDaysProvider.notifier).state = safetyStock;
    ref.invalidate(forecastItemsProvider);
  }

  Future<void> _pickDateRange(BuildContext context, DateTimeRange currentRange) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: currentRange,
    );

    if (picked != null) {
      ref.read(forecastDateRangeProvider.notifier).state = picked;
      ref.invalidate(forecastItemsProvider);
    }
  }

  Future<void> _showDetailSheet(BuildContext context, ForecastItem item) async {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.productName,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _detailRow('Current Stock', item.currentStock.toStringAsFixed(1)),
              _detailRow('Total Sold', item.totalSold.toStringAsFixed(1)),
              _detailRow('Revenue', CurrencyFormatter.format(item.totalRevenue)),
              _detailRow('Avg Daily Sales', item.avgDailySales.toStringAsFixed(2)),
              _detailRow('Forecast Days', item.forecastDays.toString()),
              _detailRow('Forecast Demand', item.forecastDemand.toStringAsFixed(1)),
              _detailRow('Suggested Reorder', item.suggestedReorder.toStringAsFixed(1)),
              _detailRow(
                'Days Coverage',
                item.daysCoverage.isInfinite ? '∞' : item.daysCoverage.toStringAsFixed(1),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Color _statusColor(ForecastStatus status) {
    switch (status) {
      case ForecastStatus.outOfStock:
        return Colors.red;
      case ForecastStatus.urgent:
        return Colors.deepOrange;
      case ForecastStatus.low:
        return Colors.orange;
      case ForecastStatus.ok:
        return Colors.green;
    }
  }

  String _statusLabel(ForecastStatus status) {
    switch (status) {
      case ForecastStatus.outOfStock:
        return 'Out of stock';
      case ForecastStatus.urgent:
        return 'Urgent';
      case ForecastStatus.low:
        return 'Low';
      case ForecastStatus.ok:
        return 'OK';
    }
  }
}
