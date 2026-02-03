import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../inventory/inventory_providers.dart';
import '../../customers/customer_providers.dart';
import '../report_providers.dart';
import '../services/pdf_export_service.dart';
import '../services/csv_export_service.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedRange = ref.watch(selectedDateRangeProvider);
    final filteredSalesAsync = ref.watch(filteredSalesProvider);
    final recentOrdersAsync = ref.watch(recentOrdersProvider);
    final paymentStatsAsync = ref.watch(filteredPaymentMethodStatsProvider);
    final topProductsAsync = ref.watch(topProductsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) => _handleMenuAction(context, ref, value),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'export_sales_pdf',
                child: Row(
                  children: [
                    Icon(Icons.picture_as_pdf),
                    SizedBox(width: 8),
                    Text('Export Sales PDF'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'export_inventory_pdf',
                child: Row(
                  children: [
                    Icon(Icons.inventory),
                    SizedBox(width: 8),
                    Text('Export Inventory PDF'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'export_customers_pdf',
                child: Row(
                  children: [
                    Icon(Icons.people),
                    SizedBox(width: 8),
                    Text('Export Customers PDF'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'export_sales_csv',
                child: Row(
                  children: [
                    Icon(Icons.file_present),
                    SizedBox(width: 8),
                    Text('Export Sales CSV'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'export_inventory_csv',
                child: Row(
                  children: [
                    Icon(Icons.file_present),
                    SizedBox(width: 8),
                    Text('Export Inventory CSV'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'export_customers_csv',
                child: Row(
                  children: [
                    Icon(Icons.file_present),
                    SizedBox(width: 8),
                    Text('Export Customers CSV'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'print_x_report',
                child: Row(
                  children: [
                    Icon(Icons.print),
                    SizedBox(width: 8),
                    Text('Print X-Report'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'print_z_report',
                child: Row(
                  children: [
                    Icon(Icons.print_outlined),
                    SizedBox(width: 8),
                    Text('Print Z-Report'),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () => context.go('/'),
          )
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
            ref.invalidate(filteredSalesProvider);
            ref.invalidate(recentOrdersProvider);
            ref.invalidate(filteredPaymentMethodStatsProvider);
            ref.invalidate(topProductsProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Date Range Filter
              SegmentedButton<DateRangeFilter>(
                segments: const [
                  ButtonSegment(value: DateRangeFilter.today, label: Text('Today')),
                  ButtonSegment(value: DateRangeFilter.week, label: Text('Week')),
                  ButtonSegment(value: DateRangeFilter.month, label: Text('Month')),
                  ButtonSegment(value: DateRangeFilter.all, label: Text('All')),
                ],
                selected: {selectedRange},
                onSelectionChanged: (newSelection) {
                  ref.read(selectedDateRangeProvider.notifier).state = newSelection.first;
                },
              ),
              const SizedBox(height: 20),

              // 1. Total Sales Card
              _SummaryCard(
                title: _getTitleForRange(selectedRange),
                valueAsync: filteredSalesAsync,
              ),
              const SizedBox(height: 20),

              // 2. Payment Methods
              Text('Payment Methods', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 10),
              _PaymentMethodStats(statsAsync: paymentStatsAsync),
              const SizedBox(height: 20),

              // 3. Top Products
              Text('Top Selling Products', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 10),
              _TopProductsList(productsAsync: topProductsAsync),
              const SizedBox(height: 20),

              // 4. Recent Orders
              Text('Recent Transactions', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 10),
              _RecentOrdersList(ordersAsync: recentOrdersAsync),
            ],
          ),
        ),
      ),
    );
  }

  String _getTitleForRange(DateRangeFilter range) {
    switch (range) {
      case DateRangeFilter.today:
        return 'Today\'s Sales';
      case DateRangeFilter.week:
        return 'This Week\'s Sales';
      case DateRangeFilter.month:
        return 'This Month\'s Sales';
      case DateRangeFilter.all:
        return 'Total Sales';
    }
  }

  void _handleMenuAction(BuildContext context, WidgetRef ref, String action) async {
    try {
      switch (action) {
        case 'export_sales_pdf':
          await _exportSalesPdf(context, ref);
          break;
        case 'export_inventory_pdf':
          await _exportInventoryPdf(context, ref);
          break;
        case 'export_customers_pdf':
          await _exportCustomersPdf(context, ref);
          break;
        case 'export_sales_csv':
          await _exportSalesCsv(context, ref);
          break;
        case 'export_inventory_csv':
          await _exportInventoryCsv(context, ref);
          break;
        case 'export_customers_csv':
          await _exportCustomersCsv(context, ref);
          break;
        case 'print_x_report':
          await _printXReport(context, ref);
          break;
        case 'print_z_report':
          await _printZReport(context, ref);
          break;
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _exportSalesPdf(BuildContext context, WidgetRef ref) async {
    final selectedRange = ref.read(selectedDateRangeProvider);
    final dateRange = _getDateRange(selectedRange);
    
    // Show loading
    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );
    }

    try {
      final ordersAsync = await ref.read(filteredOrdersProvider.future);
      final paymentStatsAsync = await ref.read(filteredPaymentMethodStatsProvider.future);
      final topProductsAsync = await ref.read(topProductsProvider.future);

      if (context.mounted) Navigator.pop(context); // Close loading

      await PdfExportService.generateSalesReport(
        startDate: dateRange.$1,
        endDate: dateRange.$2,
        orders: ordersAsync,
        paymentMethodTotals: paymentStatsAsync,
        topProducts: topProductsAsync,
      );
    } catch (e) {
      if (context.mounted) Navigator.pop(context); // Close loading
      rethrow;
    }
  }

  Future<void> _exportInventoryPdf(BuildContext context, WidgetRef ref) async {
    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );
    }

    try {
      final products = await ref.read(productListProvider.future);
      final categories = await ref.read(categoryListProvider.future);
      
      final categoryMap = Map<int, String>.fromEntries(
        categories.map((cat) => MapEntry(cat.id, cat.name)),
      );

      if (context.mounted) Navigator.pop(context);

      await PdfExportService.generateInventoryReport(
        products: products,
        categoryNames: categoryMap,
      );
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      rethrow;
    }
  }

  Future<void> _exportCustomersPdf(BuildContext context, WidgetRef ref) async {
    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );
    }

    try {
      final customers = await ref.read(customerListProvider.future);

      if (context.mounted) Navigator.pop(context);

      await PdfExportService.generateCustomerReport(customers: customers);
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      rethrow;
    }
  }

  Future<void> _exportSalesCsv(BuildContext context, WidgetRef ref) async {
    final selectedRange = ref.read(selectedDateRangeProvider);
    final dateRange = _getDateRange(selectedRange);
    
    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );
    }

    try {
      final ordersAsync = await ref.read(filteredOrdersProvider.future);
      final paymentStatsAsync = await ref.read(filteredPaymentMethodStatsProvider.future);
      final topProductsAsync = await ref.read(topProductsProvider.future);

      final filePath = await CsvExportService.exportSalesReport(
        startDate: dateRange.$1,
        endDate: dateRange.$2,
        orders: ordersAsync,
        paymentMethodTotals: paymentStatsAsync,
        topProducts: topProductsAsync,
      );

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('CSV saved to: $filePath'),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Share',
              onPressed: () => CsvExportService.shareFile(filePath),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      rethrow;
    }
  }

  Future<void> _exportInventoryCsv(BuildContext context, WidgetRef ref) async {
    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );
    }

    try {
      final products = await ref.read(productListProvider.future);
      final categories = await ref.read(categoryListProvider.future);
      
      final categoryMap = Map<int, String>.fromEntries(
        categories.map((cat) => MapEntry(cat.id, cat.name)),
      );

      final filePath = await CsvExportService.exportInventoryReport(
        products: products,
        categoryNames: categoryMap,
      );

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('CSV saved to: $filePath'),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Share',
              onPressed: () => CsvExportService.shareFile(filePath),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      rethrow;
    }
  }

  Future<void> _exportCustomersCsv(BuildContext context, WidgetRef ref) async {
    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );
    }

    try {
      final customers = await ref.read(customerListProvider.future);

      final filePath = await CsvExportService.exportCustomerReport(
        customers: customers,
      );

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('CSV saved to: $filePath'),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Share',
              onPressed: () => CsvExportService.shareFile(filePath),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      rethrow;
    }
  }

  Future<void> _printXReport(BuildContext context, WidgetRef ref) async {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Use Printer Settings to print reports.'),
        duration: Duration(seconds: 3),
      ),
    );
  }

  Future<void> _printZReport(BuildContext context, WidgetRef ref) async {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Use Printer Settings to print reports.'),
        duration: Duration(seconds: 3),
      ),
    );
  }

  (DateTime, DateTime) _getDateRange(DateRangeFilter filter) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (filter) {
      case DateRangeFilter.today:
        return (today, today.add(const Duration(days: 1)));
      case DateRangeFilter.week:
        final startOfWeek = today.subtract(Duration(days: now.weekday - 1));
        return (startOfWeek, today.add(const Duration(days: 1)));
      case DateRangeFilter.month:
        final startOfMonth = DateTime(now.year, now.month, 1);
        return (startOfMonth, today.add(const Duration(days: 1)));
      case DateRangeFilter.all:
        return (DateTime(2020, 1, 1), today.add(const Duration(days: 1)));
    }
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final AsyncValue<double> valueAsync;

  const _SummaryCard({required this.title, required this.valueAsync});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
            ),
            const SizedBox(height: 10),
            valueAsync.when(
              data: (value) => Text(
                CurrencyFormatter.format(value),
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              loading: () => const CircularProgressIndicator(),
              error: (err, _) => Text('Error: $err'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentMethodStats extends StatelessWidget {
  final AsyncValue<Map<String, double>> statsAsync;

  const _PaymentMethodStats({required this.statsAsync});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: statsAsync.when(
          data: (stats) {
            if (stats.isEmpty) return const Text('No sales yet today.');
            
            return Column(
              children: stats.entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(_getIconForMethod(entry.key), size: 20),
                          const SizedBox(width: 8),
                          Text(entry.key.toUpperCase()),
                        ],
                      ),
                      Text(
                        CurrencyFormatter.format(entry.value),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('Error: $e'),
        ),
      ),
    );
  }

  IconData _getIconForMethod(String method) {
    switch (method.toLowerCase()) {
      case 'cash': return Icons.money;
      case 'card': return Icons.credit_card;
      case 'qr': return Icons.qr_code;
      default: return Icons.payment;
    }
  }
}

class _TopProductsList extends StatelessWidget {
  final AsyncValue<List<dynamic>> productsAsync;

  const _TopProductsList({required this.productsAsync});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: productsAsync.when(
        data: (products) {
          if (products.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('No sales data available.'),
            );
          }
          return ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: products.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final product = products[index];
              return ListTile(
                leading: CircleAvatar(
                  child: Text('${index + 1}'),
                ),
                title: Text(product.productName),
                subtitle: Text('Sold: ${product.totalQuantity.toInt()} units'),
                trailing: Text(
                  CurrencyFormatter.format(product.totalRevenue),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              );
            },
          );
        },
        loading: () => const SizedBox(
          height: 100,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text('Error: $e'),
        ),
      ),
    );
  }
}

class _RecentOrdersList extends StatelessWidget {
  final AsyncValue<List<dynamic>> ordersAsync; // dynamic to avoid direct drift dependency here if possible, but List<Order> is fine

  const _RecentOrdersList({required this.ordersAsync});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ordersAsync.when(
        data: (orders) {
          if (orders.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('No orders found.'),
            );
          }
          return ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: orders.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final order = orders[index];
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.receipt)),
                title: Text(order.orderNumber),
                subtitle: Text(DateFormat('yyyy-MM-dd HH:mm').format(order.timestamp)),
                trailing: Text(
                  CurrencyFormatter.format(order.total),
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                ),
              );
            },
          );
        },
        loading: () => const SizedBox(height: 100, child: Center(child: CircularProgressIndicator())),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
