import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../orders/order_repository.dart';

final printerServiceProvider = Provider<PrinterService>((ref) {
  return PrinterService();
});

class PrinterService {
  // Deprecated - Use ThermalPrinterService from thermal_printer_service.dart instead

  Future<List<dynamic>> getBondedDevices() async {
    try {
      if (Platform.isAndroid) {
        return [];
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<bool> connect(dynamic device) async {
    try {
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> disconnect() async {
    // No-op
  }

  Future<bool> get isConnected => Future.value(false);

  // Print Receipt Logic - Deprecated
  Future<void> printReceipt({
    required String shopName,
    required String shopAddress,
    required String orderNumber,
    required DateTime date,
    required List<OrderItemData> items,
    required double total,
    required double cashReceived,
    required double change,
    required String paymentMethod,
  }) async {}

  // Print X-Report - Deprecated
  Future<void> printXReport({
    required String shopName,
    required DateTime reportDate,
    required double totalSales,
    required int totalTransactions,
    required Map<String, double> paymentMethodTotals,
    required Map<String, double> categoryTotals,
    required List<Map<String, dynamic>> topProducts,
  }) async {}

  // Print Z-Report - Deprecated
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
  }) async {}
}
