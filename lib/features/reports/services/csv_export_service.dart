import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/database/database.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../orders/order_repository.dart';

class CsvExportService {
  static final _dateFormat = DateFormat('yyyy-MM-dd');
  static final _dateTimeFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

  /// Export Sales Report to CSV
  static Future<String> exportSalesReport({
    required DateTime startDate,
    required DateTime endDate,
    required List<Order> orders,
    required Map<String, double> paymentMethodTotals,
    required List<ProductSalesData> topProducts,
  }) async {
    final List<List<dynamic>> rows = [];

    // Header
    rows.add(['SoloPoint POS - Sales Report']);
    rows.add(['Period: ${_dateFormat.format(startDate)} to ${_dateFormat.format(endDate)}']);
    rows.add(['Generated: ${_dateTimeFormat.format(DateTime.now())}']);
    rows.add([]); // Empty row

    // Summary
    final totalSales = orders.fold<double>(0, (sum, order) => sum + order.total);
    final totalOrders = orders.length;
    final averageOrder = totalOrders > 0 ? totalSales / totalOrders : 0.0;

    rows.add(['SUMMARY']);
    rows.add(['Total Sales', CurrencyFormatter.format(totalSales)]);
    rows.add(['Total Orders', totalOrders]);
    rows.add(['Average Order', CurrencyFormatter.format(averageOrder)]);
    rows.add([]); // Empty row

    // Payment Methods
    rows.add(['PAYMENT METHODS']);
    rows.add(['Method', 'Total Amount', 'Percentage']);
    final total = paymentMethodTotals.values.fold<double>(0, (sum, val) => sum + val);
    paymentMethodTotals.forEach((method, amount) {
      final percentage = total > 0 ? (amount / total * 100).toStringAsFixed(1) : '0.0';
      rows.add([method.toUpperCase(), CurrencyFormatter.format(amount), '$percentage%']);
    });
    rows.add([]); // Empty row

    // Top Products
    if (topProducts.isNotEmpty) {
      rows.add(['TOP SELLING PRODUCTS']);
      rows.add(['Product', 'Quantity Sold', 'Total Sales']);
      for (final product in topProducts.take(10)) {
        rows.add([
          product.productName,
          product.totalQuantity.toStringAsFixed(0),
          CurrencyFormatter.format(product.totalRevenue),
        ]);
      }
      rows.add([]); // Empty row
    }

    // Recent Orders
    rows.add(['RECENT ORDERS']);
    rows.add(['Order Number', 'Date', 'Payment Method', 'Total']);
    for (final order in orders.take(50)) {
      rows.add([
        order.orderNumber,
        _dateTimeFormat.format(order.timestamp),
        order.paymentMethod.toUpperCase(),
        CurrencyFormatter.format(order.total),
      ]);
    }

    // Convert to CSV
    final csv = const ListToCsvConverter().convert(rows);
    
    // Save to file
    final fileName = 'sales_report_${_dateFormat.format(startDate)}_to_${_dateFormat.format(endDate)}.csv';
    final filePath = await _saveFile(csv, fileName);
    
    return filePath;
  }

  /// Export Inventory Report to CSV
  static Future<String> exportInventoryReport({
    required List<Product> products,
    required Map<int, String> categoryNames,
  }) async {
    final List<List<dynamic>> rows = [];

    // Header
    rows.add(['SoloPoint POS - Inventory Report']);
    rows.add(['Generated: ${_dateTimeFormat.format(DateTime.now())}']);
    rows.add([]); // Empty row

    // Summary
    final totalValue = products.fold<double>(0, (sum, p) => sum + (p.price * p.stockQuantity));
    final lowStock = products.where((p) => p.trackStock && p.stockQuantity < 10).length;

    rows.add(['SUMMARY']);
    rows.add(['Total Products', products.length]);
    rows.add(['Total Value', CurrencyFormatter.format(totalValue)]);
    rows.add(['Low Stock Items', lowStock]);
    rows.add([]); // Empty row

    // Products
    rows.add(['PRODUCTS']);
    rows.add(['SKU', 'Name', 'Category', 'Price', 'Stock', 'Value', 'Barcode']);
    
    for (final product in products) {
      final category = product.categoryId != null 
          ? categoryNames[product.categoryId] ?? 'N/A' 
          : 'N/A';
      final value = product.price * product.stockQuantity;
      final stock = product.trackStock ? product.stockQuantity.toStringAsFixed(0) : 'N/A';
      
      rows.add([
        product.sku ?? '-',
        product.name,
        category,
        CurrencyFormatter.format(product.price),
        stock,
        CurrencyFormatter.format(value),
        product.barcode ?? '-',
      ]);
    }

    // Convert to CSV
    final csv = const ListToCsvConverter().convert(rows);
    
    // Save to file
    final fileName = 'inventory_report_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv';
    final filePath = await _saveFile(csv, fileName);
    
    return filePath;
  }

  /// Export Customer Report to CSV
  static Future<String> exportCustomerReport({
    required List<Customer> customers,
  }) async {
    final List<List<dynamic>> rows = [];

    // Header
    rows.add(['SoloPoint POS - Customer Report']);
    rows.add(['Generated: ${_dateTimeFormat.format(DateTime.now())}']);
    rows.add([]); // Empty row

    // Summary
    final totalSpent = customers.fold<double>(0, (sum, c) => sum + c.totalSpent);
    final totalPoints = customers.fold<int>(0, (sum, c) => sum + c.loyaltyPoints);
    final avgSpent = customers.isNotEmpty ? totalSpent / customers.length : 0.0;

    rows.add(['SUMMARY']);
    rows.add(['Total Customers', customers.length]);
    rows.add(['Total Spent', CurrencyFormatter.format(totalSpent)]);
    rows.add(['Average Spent', CurrencyFormatter.format(avgSpent)]);
    rows.add(['Total Loyalty Points', totalPoints]);
    rows.add([]); // Empty row

    // Customers
    rows.add(['CUSTOMERS']);
    rows.add(['Name', 'Phone', 'Email', 'Total Spent', 'Loyalty Points', 'Member Since']);
    
    for (final customer in customers) {
      rows.add([
        customer.name,
        customer.phone ?? '-',
        customer.email ?? '-',
        CurrencyFormatter.format(customer.totalSpent),
        customer.loyaltyPoints,
        _dateFormat.format(customer.createdAt),
      ]);
    }

    // Convert to CSV
    final csv = const ListToCsvConverter().convert(rows);
    
    // Save to file
    final fileName = 'customer_report_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv';
    final filePath = await _saveFile(csv, fileName);
    
    return filePath;
  }

  /// Save CSV file and return file path
  static Future<String> _saveFile(String csvContent, String fileName) async {
    try {
      // Get the Downloads directory
      Directory? directory;
      
      if (Platform.isAndroid) {
        // For Android, use getExternalStorageDirectory and append Downloads
        directory = await getExternalStorageDirectory();
        if (directory != null) {
          // Navigate to actual Downloads folder
          final downloadPath = '/storage/emulated/0/Download';
          directory = Directory(downloadPath);
        }
      } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        // For desktop, use getDownloadsDirectory
        directory = await getDownloadsDirectory();
      } else {
        // Fallback to application documents directory
        directory = await getApplicationDocumentsDirectory();
      }

      if (directory == null) {
        throw Exception('Could not access storage directory');
      }

      // Create SoloPoint subfolder
      final solopointDir = Directory('${directory.path}/SoloPoint');
      if (!await solopointDir.exists()) {
        await solopointDir.create(recursive: true);
      }

      // Write file
      final file = File('${solopointDir.path}/$fileName');
      await file.writeAsString(csvContent);

      return file.path;
    } catch (e) {
      throw Exception('Failed to save CSV file: $e');
    }
  }

  /// Share CSV file using share dialog
  static Future<void> shareFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await Share.shareXFiles(
          [XFile(filePath)],
          subject: 'SoloPoint Export',
        );
      } else {
        throw Exception('File not found');
      }
    } catch (e) {
      throw Exception('Failed to share file: $e');
    }
  }
}
