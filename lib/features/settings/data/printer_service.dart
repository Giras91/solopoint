import 'dart:io';
import 'dart:typed_data';
// import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../orders/order_repository.dart';

final printerServiceProvider = Provider<PrinterService>((ref) {
  return PrinterService();
});

class PrinterService {
  // final BlueThermalPrinter _bluetooth = BlueThermalPrinter.instance;

  Future<List<dynamic>> getBondedDevices() async {
    try {
      if (Platform.isAndroid) {
        // return await _bluetooth.getBondedDevices();
        return [];
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<bool> connect(dynamic device) async {
    try {
      // if (await _bluetooth.isConnected == true) return true;
      // await _bluetooth.connect(device);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> disconnect() async {
    // if (await _bluetooth.isConnected == true) {
    //   await _bluetooth.disconnect();
    // }
  }

  Future<bool> get isConnected => Future.value(false); // _bluetooth.isConnected.then((v) => v ?? false);

  // Print Receipt Logic
  Future<void> printReceipt({
    required String shopName,
    required String shopAddress,
    required String orderNumber,
    required DateTime date,
    required List<OrderItemData> items, // Using DTO
    required double total,
    required double cashReceived,
    required double change,
    required String paymentMethod,
  }) async {
    if ((await isConnected) == false) return;

    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, profile); // Standard 58mm thermal
    List<int> bytes = [];

    // 1. Header
    bytes += generator.text(shopName,
        styles: const PosStyles(
          align: PosAlign.center,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
          bold: true,
        ));
    bytes += generator.text(shopAddress, styles: const PosStyles(align: PosAlign.center));
    bytes += generator.feed(1);

    bytes += generator.text('Date: ${DateFormat('yyyy-MM-dd HH:mm').format(date)}');
    bytes += generator.text('Order: $orderNumber');
    bytes += generator.hr();

    // 2. Items
    for (var item in items) {
      bytes += generator.row([
        PosColumn(
          text: '${item.quantity.toInt()}x ${item.productName}',
          width: 8,
          styles: const PosStyles(align: PosAlign.left),
        ),
        PosColumn(
          text: CurrencyFormatter.format(item.total),
          width: 4,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
    }
    
    bytes += generator.hr();

    // 3. Totals
    bytes += generator.row([
      PosColumn(text: 'TOTAL', width: 6, styles: const PosStyles(bold: true)),
      PosColumn(
        text: CurrencyFormatter.format(total),
        width: 6,
        styles: const PosStyles(align: PosAlign.right, bold: true),
      ),
    ]);

    if (paymentMethod == 'cash') {
      bytes += generator.row([
        PosColumn(text: 'Cash', width: 6),
        PosColumn(
          text: CurrencyFormatter.format(cashReceived),
          width: 6,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
      bytes += generator.row([
        PosColumn(text: 'Change', width: 6),
        PosColumn(
          text: CurrencyFormatter.format(change),
          width: 6,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
    } else {
        bytes += generator.row([
        PosColumn(text: 'Method', width: 6),
        PosColumn(
          text: paymentMethod.toUpperCase(),
          width: 6,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
    }

    // 4. Footer
    bytes += generator.feed(2);
    bytes += generator.text('Thank you for visiting!',
        styles: const PosStyles(align: PosAlign.center, bold: true));
    bytes += generator.feed(1);
    bytes += generator.cut();

    // Send to printer
    // await _bluetooth.writeBytes(Uint8List.fromList(bytes));
  }

  /// Print X-Report (Mid-day report without clearing data)
  Future<void> printXReport({
    required String shopName,
    required DateTime reportDate,
    required double totalSales,
    required int totalTransactions,
    required Map<String, double> paymentMethodTotals,
    required Map<String, double> categoryTotals,
    required List<Map<String, dynamic>> topProducts,
  }) async {
    if ((await isConnected) == false) return;

    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, profile);
    List<int> bytes = [];

    // Header
    bytes += generator.text(shopName,
        styles: const PosStyles(
          align: PosAlign.center,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
          bold: true,
        ));
    bytes += generator.feed(1);
    bytes += generator.text('X-REPORT (CURRENT SALES)',
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size1,
          width: PosTextSize.size2,
        ));
    bytes += generator.text(
      DateFormat('yyyy-MM-dd HH:mm').format(reportDate),
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += generator.hr();

    // Summary
    bytes += generator.text('SALES SUMMARY',
        styles: const PosStyles(bold: true, align: PosAlign.center));
    bytes += generator.feed(1);
    
    bytes += generator.row([
      PosColumn(text: 'Total Sales:', width: 6),
      PosColumn(
        text: CurrencyFormatter.format(totalSales),
        width: 6,
        styles: const PosStyles(align: PosAlign.right, bold: true),
      ),
    ]);
    
    bytes += generator.row([
      PosColumn(text: 'Transactions:', width: 6),
      PosColumn(
        text: totalTransactions.toString(),
        width: 6,
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);
    
    final avgTransaction = totalTransactions > 0 ? totalSales / totalTransactions : 0.0;
    bytes += generator.row([
      PosColumn(text: 'Avg Order:', width: 6),
      PosColumn(
        text: CurrencyFormatter.format(avgTransaction),
        width: 6,
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);
    
    bytes += generator.hr();

    // Payment Methods
    bytes += generator.text('PAYMENT METHODS',
        styles: const PosStyles(bold: true, align: PosAlign.center));
    bytes += generator.feed(1);
    
    paymentMethodTotals.forEach((method, amount) {
      bytes += generator.row([
        PosColumn(text: method.toUpperCase(), width: 6),
        PosColumn(
          text: CurrencyFormatter.format(amount),
          width: 6,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
    });
    
    bytes += generator.hr();

    // Category Breakdown
    if (categoryTotals.isNotEmpty) {
      bytes += generator.text('CATEGORY BREAKDOWN',
          styles: const PosStyles(bold: true, align: PosAlign.center));
      bytes += generator.feed(1);
      
      categoryTotals.forEach((category, amount) {
        bytes += generator.row([
          PosColumn(text: category, width: 6),
          PosColumn(
            text: CurrencyFormatter.format(amount),
            width: 6,
            styles: const PosStyles(align: PosAlign.right),
          ),
        ]);
      });
      
      bytes += generator.hr();
    }

    // Top Products
    if (topProducts.isNotEmpty) {
      bytes += generator.text('TOP PRODUCTS',
          styles: const PosStyles(bold: true, align: PosAlign.center));
      bytes += generator.feed(1);
      
      for (final product in topProducts.take(5)) {
        bytes += generator.row([
          PosColumn(
            text: '${product['quantity']}x ${product['name']}',
            width: 8,
          ),
          PosColumn(
            text: CurrencyFormatter.format(product['total']),
            width: 4,
            styles: const PosStyles(align: PosAlign.right),
          ),
        ]);
      }
      
      bytes += generator.hr();
    }

    // Footer
    bytes += generator.feed(1);
    bytes += generator.text('** X-REPORT **',
        styles: const PosStyles(align: PosAlign.center, bold: true));
    bytes += generator.text('(Current Sales - Not Cleared)',
        styles: const PosStyles(align: PosAlign.center));
    bytes += generator.feed(2);
    bytes += generator.cut();

    // await _bluetooth.writeBytes(Uint8List.fromList(bytes));
  }

  /// Print Z-Report (End of day report)
  Future<void> printZReport({
    required String shopName,
    required DateTime reportDate,
    required DateTime startDate,
    required DateTime endDate,
    required double totalSales,
    required int totalTransactions,
    required Map<String, double> paymentMethodTotals,
    required Map<String, double> categoryTotals,
    required List<Map<String, dynamic>> topProducts,
    required int reportNumber,
  }) async {
    // Printer disabled for now - would require blue_thermal_printer
  }
}
