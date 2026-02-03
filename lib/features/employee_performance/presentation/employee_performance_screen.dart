import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/currency_formatter.dart';
import '../employee_performance_providers.dart';
import '../employee_performance_repository.dart';

class EmployeePerformanceScreen extends ConsumerWidget {
  const EmployeePerformanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(employeePerformanceDateRangeProvider);
    final performanceAsync = ref.watch(employeePerformanceProvider);
    final formatter = DateFormat('MMM dd, yyyy');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Employee Performance'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () => _pickDateRange(context, ref, range),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(employeePerformanceProvider),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
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
                        onPressed: () => _pickDateRange(context, ref, range),
                        icon: const Icon(Icons.edit),
                        label: const Text('Change'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              performanceAsync.when(
                data: (items) => _buildPerformanceList(items),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, st) => Center(child: Text('Error: $err')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPerformanceList(List<EmployeePerformance> items) {
    if (items.isEmpty) {
      return const Center(child: Text('No performance data found.'));
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = items[index];
        return ListTile(
          leading: CircleAvatar(
            child: Text(
              item.name.isNotEmpty ? item.name[0].toUpperCase() : '?',
            ),
          ),
          title: Text(item.name),
          subtitle: Text('${item.role} • Orders: ${item.totalOrders}'),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                CurrencyFormatter.format(item.totalSales),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                'AOV ${CurrencyFormatter.format(item.averageOrderValue)}',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
          onTap: () => _showDetails(context, item),
        );
      },
    );
  }

  void _showDetails(BuildContext context, EmployeePerformance item) {
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
                item.name,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _detailRow('Role', item.role),
              _detailRow('Total Sales', CurrencyFormatter.format(item.totalSales)),
              _detailRow('Total Orders', item.totalOrders.toString()),
              _detailRow('Average Order', CurrencyFormatter.format(item.averageOrderValue)),
              _detailRow('Total Discount', CurrencyFormatter.format(item.totalDiscount)),
              _detailRow('Total Tax', CurrencyFormatter.format(item.totalTax)),
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

  Future<void> _pickDateRange(
    BuildContext context,
    WidgetRef ref,
    DateTimeRange range,
  ) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: range,
    );

    if (picked != null) {
      ref.read(employeePerformanceDateRangeProvider.notifier).state = picked;
      ref.invalidate(employeePerformanceProvider);
    }
  }
}
