import 'dart:typed_data';
import 'package:flutter_pos_printer_platform/flutter_pos_printer_platform.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../orders/order_repository.dart';
import '../../../core/utils/currency_formatter.dart';

enum ThermalPaperSize { mm58, mm80 }

enum AppPrinterType { bluetooth, usb, network }

class AppPrinterDevice {
  final String id;
  final String name;
  final AppPrinterType type;
  final String? address;
  final bool isBle;
  final int? vendorId;
  final int? productId;
  final int? port;

  const AppPrinterDevice({
    required this.id,
    required this.name,
    required this.type,
    this.address,
    this.isBle = false,
    this.vendorId,
    this.productId,
    this.port,
  });
}

class ThermalPrinterConfig {
  final ThermalPaperSize paperSize;
  final AppPrinterDevice? savedPrinter;

  const ThermalPrinterConfig({
    this.paperSize = ThermalPaperSize.mm80,
    this.savedPrinter,
  });

  int get dotsWidth => paperSize == ThermalPaperSize.mm58 ? 384 : 576;
  int get charsPerLine => paperSize == ThermalPaperSize.mm58 ? 32 : 48;
}

final thermalPrinterServiceProvider = Provider<ThermalPrinterService>((ref) {
  return ThermalPrinterService();
});

final thermalPrinterConfigProvider = StateProvider<ThermalPrinterConfig>((ref) {
  return const ThermalPrinterConfig();
});

class ThermalPrinterService {
  final PrinterManager _printerManager = PrinterManager.instance;
  AppPrinterDevice? _currentDevice;

  bool get isConnected => _currentDevice != null;
  AppPrinterDevice? get currentDevice => _currentDevice;

  Future<void> savePrinterConfig(AppPrinterDevice device) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('printer_type', device.type.name);
    await prefs.setString('printer_name', device.name);
    await prefs.setString('printer_address', device.address ?? '');
    await prefs.setBool('printer_is_ble', device.isBle);
    if (device.vendorId != null) {
      await prefs.setInt('printer_vendor_id', device.vendorId!);
    }
    if (device.productId != null) {
      await prefs.setInt('printer_product_id', device.productId!);
    }
    if (device.port != null) {
      await prefs.setInt('printer_port', device.port!);
    }
  }

  Future<AppPrinterDevice?> loadSavedPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    final typeName = prefs.getString('printer_type');
    final name = prefs.getString('printer_name');
    final address = prefs.getString('printer_address');
    final isBle = prefs.getBool('printer_is_ble') ?? false;
    final vendorId = prefs.getInt('printer_vendor_id');
    final productId = prefs.getInt('printer_product_id');
    final port = prefs.getInt('printer_port');

    if (typeName == null || name == null || address == null || address.isEmpty) {
      return null;
    }

    final type = AppPrinterType.values.firstWhere(
      (value) => value.name == typeName,
      orElse: () => AppPrinterType.network,
    );

    return AppPrinterDevice(
      id: 'saved_${type.name}_$address',
      name: name,
      type: type,
      address: address,
      isBle: isBle,
      vendorId: vendorId,
      productId: productId,
      port: port,
    );
  }

  Future<List<AppPrinterDevice>> discoverBluetoothPrinters() async {
    try {
      final devices = await _printerManager.discovery(type: PrinterType.bluetooth).toList();
        return devices
          .where((device) => (device.name?.isNotEmpty ?? false) || (device.address?.isNotEmpty ?? false))
          .map(
            (device) => AppPrinterDevice(
              id: 'bt_${device.address ?? device.name ?? 'unknown'}',
              name: device.name ?? device.address ?? 'Unknown Printer',
              type: AppPrinterType.bluetooth,
              address: device.address,
              isBle: false,
            ),
          )
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<AppPrinterDevice>> discoverUsbPrinters() async {
    try {
      final devices = await _printerManager.discovery(type: PrinterType.usb).toList();
        return devices
          .where((device) => (device.name?.isNotEmpty ?? false) || (device.address?.isNotEmpty ?? false))
          .map(
            (device) => AppPrinterDevice(
              id: 'usb_${device.name ?? device.address ?? 'unknown'}',
              name: device.name ?? device.address ?? 'Unknown Printer',
              type: AppPrinterType.usb,
              vendorId: _parseVendorId(device.vendorId),
              productId: _parseProductId(device.productId),
            ),
          )
          .toList();
    } catch (e) {
      return [];
    }
  }

  AppPrinterDevice createNetworkPrinter(String ipAddress, {int port = 9100}) {
    return AppPrinterDevice(
      id: 'net_$ipAddress:$port',
      name: 'Network Printer ($ipAddress)',
      type: AppPrinterType.network,
      address: ipAddress,
      port: port,
    );
  }

  Future<bool> connect(AppPrinterDevice device) async {
    try {
      await disconnect();

      switch (device.type) {
        case AppPrinterType.bluetooth:
          if (device.address == null) return false;
          await _printerManager.connect(
            type: PrinterType.bluetooth,
            model: BluetoothPrinterInput(
              name: device.name,
              address: device.address!,
              isBle: device.isBle,
              autoConnect: true,
            ),
          );
          break;
        case AppPrinterType.usb:
          await _printerManager.connect(
            type: PrinterType.usb,
            model: UsbPrinterInput(
              name: device.name,
              vendorId: device.vendorId?.toString(),
              productId: device.productId?.toString(),
            ),
          );
          break;
        case AppPrinterType.network:
          if (device.address == null) return false;
          await _printerManager.connect(
            type: PrinterType.network,
            model: TcpPrinterInput(
              ipAddress: device.address!,
              port: device.port ?? 9100,
            ),
          );
          break;
      }

      _currentDevice = device;
      await savePrinterConfig(device);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> disconnect() async {
    if (_currentDevice == null) return;

    final type = _currentDevice!.type == AppPrinterType.bluetooth
        ? PrinterType.bluetooth
        : _currentDevice!.type == AppPrinterType.usb
            ? PrinterType.usb
            : PrinterType.network;

    try {
      await _printerManager.disconnect(type: type);
    } catch (e) {
      // Ignore disconnect errors
    }
    _currentDevice = null;
  }

  int? _parseVendorId(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  int? _parseProductId(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  Future<bool> _sendBytes(List<int> bytes) async {
    if (_currentDevice == null) return false;

    final type = _currentDevice!.type == AppPrinterType.bluetooth
        ? PrinterType.bluetooth
        : _currentDevice!.type == AppPrinterType.usb
            ? PrinterType.usb
            : PrinterType.network;

    try {
      await _printerManager.send(
        type: type,
        bytes: Uint8List.fromList(bytes),
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> printReceipt({
    required ThermalPrinterConfig config,
    required String shopName,
    String? shopAddress,
    String? shopPhone,
    required String orderNumber,
    required DateTime date,
    required List<OrderItemData> items,
    required double subtotal,
    required double tax,
    required double discount,
    required double total,
    required double cashReceived,
    required double change,
    required String paymentMethod,
    String? footerText,
    String? customerName,
  }) async {
    if (!isConnected) return false;

    try {
      List<int> bytes = [];
      // ESC/POS commands for simple text receipt
      final charsPerLine = config.charsPerLine;
      
      // Reset printer
      bytes.addAll([27, 64]); // ESC @
      
      // Center align
      bytes.addAll([27, 97, 1]); // ESC a 1 (center)
      
      // Bold on
      bytes.addAll([27, 69, 1]); // ESC E 1
      
      // Add text with padding
      bytes.addAll(_encodeLine(shopName, charsPerLine));
      
      // Bold off
      bytes.addAll([27, 69, 0]); // ESC E 0
      
      if (shopAddress != null) {
        bytes.addAll(_encodeLine(shopAddress, charsPerLine));
      }
      
      if (shopPhone != null) {
        bytes.addAll(_encodeLine('Tel: $shopPhone', charsPerLine));
      }
      
      // Left align
      bytes.addAll([27, 97, 0]); // ESC a 0 (left)
      
      // Separator line
      bytes.addAll(_encodeLine(_repeatChar('-', charsPerLine), charsPerLine));
      
      bytes.addAll(_encodeLine('Order #$orderNumber', charsPerLine));
      bytes.addAll(_encodeLine(DateFormat('yyyy-MM-dd HH:mm:ss').format(date), charsPerLine));
      
      if (customerName != null) {
        bytes.addAll(_encodeLine('Customer: $customerName', charsPerLine));
      }
      
      bytes.addAll(_encodeLine(_repeatChar('-', charsPerLine), charsPerLine));
      
      // Items
      bytes.addAll([27, 69, 1]); // Bold on
      bytes.addAll(_encodeLine('ITEMS', charsPerLine));
      bytes.addAll([27, 69, 0]); // Bold off
      
      for (final item in items) {
        final qtyStr = '${item.quantity.toInt()}x';
        final priceStr = CurrencyFormatter.format(item.total);
        final itemLine = _padLine(item.productName, charsPerLine - qtyStr.length - priceStr.length) + qtyStr + priceStr;
        bytes.addAll(_encodeLine(itemLine, charsPerLine));
        
        for (final modifier in item.modifiers) {
          bytes.addAll(_encodeLine('  + ${modifier.itemName}', charsPerLine));
        }
      }
      
      bytes.addAll(_encodeLine(_repeatChar('-', charsPerLine), charsPerLine));
      
      // Totals
      bytes.addAll(_encodeLine(_padLine('Subtotal', charsPerLine - CurrencyFormatter.format(subtotal).length) + CurrencyFormatter.format(subtotal), charsPerLine));
      
      if (tax > 0) {
        bytes.addAll(_encodeLine(_padLine('Tax', charsPerLine - CurrencyFormatter.format(tax).length) + CurrencyFormatter.format(tax), charsPerLine));
      }
      
      if (discount > 0) {
        final discountStr = CurrencyFormatter.format(discount);
        bytes.addAll(_encodeLine(_padLine('Discount', charsPerLine - discountStr.length - 1) + '-$discountStr', charsPerLine));
      }
      
      bytes.addAll(_encodeLine(_repeatChar('=', charsPerLine), charsPerLine));
      
      // Total (bold, large)
      bytes.addAll([27, 69, 1]); // Bold on
      bytes.addAll([27, 33, 48]); // Double size
      bytes.addAll(_encodeLine(_padLine('TOTAL', charsPerLine - CurrencyFormatter.format(total).length) + CurrencyFormatter.format(total), charsPerLine));
      bytes.addAll([27, 33, 0]); // Normal size
      bytes.addAll([27, 69, 0]); // Bold off
      
      bytes.addAll(_encodeLine(_repeatChar('=', charsPerLine), charsPerLine));
      
      // Payment info
      bytes.addAll(_encodeLine(_padLine('Payment', charsPerLine - paymentMethod.length) + paymentMethod.toUpperCase(), charsPerLine));
      
      if (paymentMethod.toLowerCase() == 'cash') {
        bytes.addAll(_encodeLine(_padLine('Cash', charsPerLine - CurrencyFormatter.format(cashReceived).length) + CurrencyFormatter.format(cashReceived), charsPerLine));
        bytes.addAll(_encodeLine(_padLine('Change', charsPerLine - CurrencyFormatter.format(change).length) + CurrencyFormatter.format(change), charsPerLine));
      }
      
      // Footer
      bytes.addAll([27, 97, 1]); // Center
      bytes.addAll(_encodeLine(footerText ?? 'Thank you for your purchase!', charsPerLine));
      bytes.addAll([27, 97, 0]); // Left
      
      // Feed and cut
      bytes.addAll([10, 10]); // Two line feeds
      bytes.addAll([27, 105]); // ESC i (partial cut)
      
      return await _sendBytes(bytes);
    } catch (e) {
      return false;
    }
  }

  List<int> _encodeLine(String text, int maxWidth) {
    // Trim and pad text to maxWidth
    String line = text.length > maxWidth ? text.substring(0, maxWidth) : _padLine(text, maxWidth);
    final bytes = <int>[];
    bytes.addAll(line.codeUnits);
    bytes.add(10); // LF (line feed)
    return bytes;
  }

  String _padLine(String text, int width) {
    if (text.length >= width) return text.substring(0, width);
    return text + ' ' * (width - text.length);
  }

  String _repeatChar(String char, int count) {
    return char * count;
  }
}

