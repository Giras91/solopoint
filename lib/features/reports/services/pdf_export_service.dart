import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../../../core/database/database.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../orders/order_repository.dart';

class PdfExportService {
  static final _currencyFormat = NumberFormat.currency(symbol: CurrencyFormatter.currencySymbol);
  static final _dateFormat = DateFormat('MMM dd, yyyy');
  static final _dateTimeFormat = DateFormat('MMM dd, yyyy hh:mm a');

  /// Generate Sales Report PDF
  static Future<void> generateSalesReport({
    required DateTime startDate,
    required DateTime endDate,
    required List<Order> orders,
    required Map<String, double> paymentMethodTotals,
    required List<ProductSalesData> topProducts,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          // Header
          pw.Header(
            level: 0,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'SoloPoint POS',
                  style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Sales Report',
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Period: ${_dateFormat.format(startDate)} - ${_dateFormat.format(endDate)}',
                  style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
                ),
                pw.Divider(thickness: 2),
              ],
            ),
          ),

          // Summary Section
          pw.SizedBox(height: 20),
          pw.Text('Summary', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          _buildSummaryGrid(orders, paymentMethodTotals),

          // Payment Methods Section
          pw.SizedBox(height: 20),
          pw.Text('Payment Methods', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          _buildPaymentMethodsTable(paymentMethodTotals),

          // Top Products Section
          if (topProducts.isNotEmpty) ...[
            pw.SizedBox(height: 20),
            pw.Text('Top Selling Products', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            _buildTopProductsTable(topProducts),
          ],

          // Recent Orders Section
          pw.SizedBox(height: 20),
          pw.Text('Recent Orders', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          _buildOrdersTable(orders.take(20).toList()),

          // Footer
          pw.SizedBox(height: 20),
          pw.Divider(),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Generated: ${_dateTimeFormat.format(DateTime.now())}',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
              ),
              pw.Text(
                'Page ${context.pageNumber} of ${context.pagesCount}',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
              ),
            ],
          ),
        ],
      ),
    );

    // Show print preview dialog
    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'sales_report_${_dateFormat.format(startDate)}_to_${_dateFormat.format(endDate)}.pdf',
    );
  }

  static pw.Widget _buildSummaryGrid(List<Order> orders, Map<String, double> paymentMethodTotals) {
    final totalSales = orders.fold<double>(0, (sum, order) => sum + order.total);
    final totalOrders = orders.length;
    final averageOrder = totalOrders > 0 ? totalSales / totalOrders : 0.0;

    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem('Total Sales', _currencyFormat.format(totalSales)),
          _buildSummaryItem('Total Orders', totalOrders.toString()),
          _buildSummaryItem('Average Order', _currencyFormat.format(averageOrder)),
        ],
      ),
    );
  }

  static pw.Widget _buildSummaryItem(String label, String value) {
    return pw.Column(
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
        pw.SizedBox(height: 4),
        pw.Text(value, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
      ],
    );
  }

  static pw.Widget _buildPaymentMethodsTable(Map<String, double> paymentMethodTotals) {
    return pw.Table.fromTextArray(
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
      cellAlignment: pw.Alignment.centerLeft,
      headers: ['Payment Method', 'Total Amount', 'Percentage'],
      data: paymentMethodTotals.entries.map((entry) {
        final total = paymentMethodTotals.values.fold<double>(0, (sum, val) => sum + val);
        final percentage = total > 0 ? (entry.value / total * 100).toStringAsFixed(1) : '0.0';
        return [
          entry.key.toUpperCase(),
          _currencyFormat.format(entry.value),
          '$percentage%',
        ];
      }).toList(),
    );
  }

  static pw.Widget _buildTopProductsTable(List<ProductSalesData> topProducts) {
    return pw.Table.fromTextArray(
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
      cellAlignment: pw.Alignment.centerLeft,
      headers: ['Product', 'Quantity Sold', 'Total Sales'],
      data: topProducts.take(10).map((product) {
        return [
          product.productName,
          product.totalQuantity.toStringAsFixed(0),
          _currencyFormat.format(product.totalRevenue),
        ];
      }).toList(),
    );
  }

  static pw.Widget _buildOrdersTable(List<Order> orders) {
    return pw.Table.fromTextArray(
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
      cellAlignment: pw.Alignment.centerLeft,
      headers: ['Order #', 'Date', 'Payment', 'Total'],
      data: orders.map((order) {
        return [
          order.orderNumber,
          _dateTimeFormat.format(order.timestamp),
          order.paymentMethod.toUpperCase(),
          _currencyFormat.format(order.total),
        ];
      }).toList(),
    );
  }

  /// Generate Inventory Report PDF
  static Future<void> generateInventoryReport({
    required List<Product> products,
    required Map<int, String> categoryNames,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          // Header
          pw.Header(
            level: 0,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'SoloPoint POS',
                  style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Inventory Report',
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Generated: ${_dateTimeFormat.format(DateTime.now())}',
                  style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
                ),
                pw.Divider(thickness: 2),
              ],
            ),
          ),

          // Summary
          pw.SizedBox(height: 20),
          _buildInventorySummary(products),

          // Products Table
          pw.SizedBox(height: 20),
          pw.Text('Products', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          _buildInventoryTable(products, categoryNames),

          // Footer
          pw.SizedBox(height: 20),
          pw.Divider(),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Total Products: ${products.length}',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
              ),
              pw.Text(
                'Page ${context.pageNumber} of ${context.pagesCount}',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
              ),
            ],
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'inventory_report_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
    );
  }

  static pw.Widget _buildInventorySummary(List<Product> products) {
    final totalValue = products.fold<double>(0, (sum, p) => sum + (p.price * p.stockQuantity));
    final lowStock = products.where((p) => p.trackStock && p.stockQuantity < 10).length;

    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem('Total Products', products.length.toString()),
          _buildSummaryItem('Total Value', _currencyFormat.format(totalValue)),
          _buildSummaryItem('Low Stock Items', lowStock.toString()),
        ],
      ),
    );
  }

  static pw.Widget _buildInventoryTable(List<Product> products, Map<int, String> categoryNames) {
    return pw.Table.fromTextArray(
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
      cellStyle: const pw.TextStyle(fontSize: 9),
      cellAlignment: pw.Alignment.centerLeft,
      headers: ['SKU', 'Product', 'Category', 'Price', 'Stock', 'Value'],
      data: products.map((product) {
        final category = product.categoryId != null ? categoryNames[product.categoryId] ?? 'N/A' : 'N/A';
        final value = product.price * product.stockQuantity;
        return [
          product.sku ?? '-',
          product.name,
          category,
          _currencyFormat.format(product.price),
          product.trackStock ? product.stockQuantity.toStringAsFixed(0) : 'N/A',
          _currencyFormat.format(value),
        ];
      }).toList(),
    );
  }

  /// Generate Customer Report PDF
  static Future<void> generateCustomerReport({
    required List<Customer> customers,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          // Header
          pw.Header(
            level: 0,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'SoloPoint POS',
                  style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Customer Report',
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Generated: ${_dateTimeFormat.format(DateTime.now())}',
                  style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
                ),
                pw.Divider(thickness: 2),
              ],
            ),
          ),

          // Summary
          pw.SizedBox(height: 20),
          _buildCustomerSummary(customers),

          // Customers Table
          pw.SizedBox(height: 20),
          pw.Text('Customers', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          _buildCustomersTable(customers),

          // Footer
          pw.SizedBox(height: 20),
          pw.Divider(),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Total Customers: ${customers.length}',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
              ),
              pw.Text(
                'Page ${context.pageNumber} of ${context.pagesCount}',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
              ),
            ],
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'customer_report_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
    );
  }

  static pw.Widget _buildCustomerSummary(List<Customer> customers) {
    final totalSpent = customers.fold<double>(0, (sum, c) => sum + c.totalSpent);
    final totalPoints = customers.fold<int>(0, (sum, c) => sum + c.loyaltyPoints);
    final avgSpent = customers.isNotEmpty ? totalSpent / customers.length : 0.0;

    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem('Total Customers', customers.length.toString()),
          _buildSummaryItem('Total Spent', _currencyFormat.format(totalSpent)),
          _buildSummaryItem('Average Spent', _currencyFormat.format(avgSpent)),
          _buildSummaryItem('Total Points', totalPoints.toString()),
        ],
      ),
    );
  }

  static pw.Widget _buildCustomersTable(List<Customer> customers) {
    return pw.Table.fromTextArray(
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
      cellStyle: const pw.TextStyle(fontSize: 9),
      cellAlignment: pw.Alignment.centerLeft,
      headers: ['Name', 'Phone', 'Email', 'Total Spent', 'Loyalty Points'],
      data: customers.map((customer) {
        return [
          customer.name,
          customer.phone ?? '-',
          customer.email ?? '-',
          _currencyFormat.format(customer.totalSpent),
          customer.loyaltyPoints.toString(),
        ];
      }).toList(),
    );
  }
}
