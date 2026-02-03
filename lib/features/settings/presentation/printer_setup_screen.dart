import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/thermal_printer_service.dart';

final isDiscoveringProvider = StateProvider<bool>((ref) => false);
final discoveredPrintersProvider = StateProvider<List<AppPrinterDevice>>((ref) => []);
final currentDeviceProvider = StateProvider<AppPrinterDevice?>((ref) => null);

class PrinterSetupScreen extends ConsumerStatefulWidget {
  const PrinterSetupScreen({super.key});

  @override
  ConsumerState<PrinterSetupScreen> createState() => _PrinterSetupScreenState();
}

class _PrinterSetupScreenState extends ConsumerState<PrinterSetupScreen> {
  final _ipController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSavedPrinter();
  }

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedPrinter() async {
    final service = ref.read(thermalPrinterServiceProvider);
    final savedPrinter = await service.loadSavedPrinter();
    if (savedPrinter != null) {
      ref.read(currentDeviceProvider.notifier).state = savedPrinter;
    }
  }

  Future<void> _discoverBluetoothPrinters() async {
    ref.read(isDiscoveringProvider.notifier).state = true;
    final service = ref.read(thermalPrinterServiceProvider);

    try {
      final printers = await service.discoverBluetoothPrinters();
      ref.read(discoveredPrintersProvider.notifier).state = printers;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Found ${printers.length} Bluetooth printer(s)')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      ref.read(isDiscoveringProvider.notifier).state = false;
    }
  }

  Future<void> _discoverUsbPrinters() async {
    ref.read(isDiscoveringProvider.notifier).state = true;
    final service = ref.read(thermalPrinterServiceProvider);

    try {
      final printers = await service.discoverUsbPrinters();
      ref.read(discoveredPrintersProvider.notifier).state = printers;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Found ${printers.length} USB printer(s)')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      ref.read(isDiscoveringProvider.notifier).state = false;
    }
  }

  Future<void> _connectToPrinter(AppPrinterDevice device) async {
    final service = ref.read(thermalPrinterServiceProvider);
    
    try {
      final success = await service.connect(device);
      if (success) {
        ref.read(currentDeviceProvider.notifier).state = device;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Connected to ${device.name}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to connect'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _disconnectPrinter() async {
    final service = ref.read(thermalPrinterServiceProvider);
    await service.disconnect();
    ref.read(currentDeviceProvider.notifier).state = null;
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Printer disconnected')),
      );
    }
  }

  Future<void> _testPrint() async {
    final service = ref.read(thermalPrinterServiceProvider);
    final config = ref.read(thermalPrinterConfigProvider);
    
    if (!service.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No printer connected'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    try {
      final success = await service.printReceipt(
        config: config,
        shopName: 'SOLOPOINT POS',
        shopAddress: 'Test Location - Malaysia',
        shopPhone: '+60 123-456-7890',
        orderNumber: 'TEST-001',
        date: DateTime.now(),
        items: [],
        subtotal: 0,
        tax: 0,
        discount: 0,
        total: 0,
        cashReceived: 0,
        change: 0,
        paymentMethod: 'Test',
        footerText: 'This is a test print from ${config.paperSize == ThermalPaperSize.mm58 ? "58mm" : "80mm"} printer',
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Test print sent!' : 'Test print failed'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
  @override
  Widget build(BuildContext context) {
    final isDiscovering = ref.watch(isDiscoveringProvider);
    final discoveredPrinters = ref.watch(discoveredPrintersProvider);
    final currentDevice = ref.watch(currentDeviceProvider);
    final config = ref.watch(thermalPrinterConfigProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thermal Printer Setup'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Paper Size Selection
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Paper Size',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    SegmentedButton<ThermalPaperSize>(
                      segments: const [
                        ButtonSegment(
                          value: ThermalPaperSize.mm58,
                          label: Text('58mm'),
                          icon: Icon(Icons.receipt),
                        ),
                        ButtonSegment(
                          value: ThermalPaperSize.mm80,
                          label: Text('80mm'),
                          icon: Icon(Icons.receipt_long),
                        ),
                      ],
                      selected: {config.paperSize},
                      onSelectionChanged: (Set<ThermalPaperSize> newSelection) {
                        ref.read(thermalPrinterConfigProvider.notifier).state = ThermalPrinterConfig(
                          paperSize: newSelection.first,
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      config.paperSize == ThermalPaperSize.mm58
                          ? '58mm: Mobile/Handheld POS (32 chars/line)'
                          : '80mm: Desktop/Kitchen Printers (48 chars/line)',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.outline),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Connection Status
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          currentDevice != null ? Icons.check_circle : Icons.error_outline,
                          color: currentDevice != null ? Colors.green : Colors.grey,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Connection Status',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                currentDevice != null
                                    ? 'Connected to ${currentDevice.name}'
                                    : 'No printer connected',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: colorScheme.outline,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (currentDevice != null) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _testPrint,
                              icon: const Icon(Icons.print),
                              label: const Text('Test Print'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colorScheme.primary,
                                foregroundColor: colorScheme.onPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _disconnectPrinter,
                              icon: const Icon(Icons.link_off),
                              label: const Text('Disconnect'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Bluetooth Printers
            Text(
              'Bluetooth Printers',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: isDiscovering ? null : _discoverBluetoothPrinters,
                        icon: isDiscovering
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.bluetooth),
                        label: Text(isDiscovering ? 'Scanning...' : 'Scan Bluetooth'),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // USB Printers
            Text(
              'USB Printers',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: isDiscovering ? null : _discoverUsbPrinters,
                        icon: isDiscovering
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.usb),
                        label: Text(isDiscovering ? 'Scanning...' : 'Scan USB'),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Discovered Printers
            if (discoveredPrinters.isNotEmpty) ...[
              Text(
                'Discovered Printers',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ...discoveredPrinters.map((printer) {
                final isConnected = currentDevice?.id == printer.id;
                return Card(
                  color: isConnected ? colorScheme.primaryContainer : null,
                  child: ListTile(
                    leading: Icon(
                      printer.type == AppPrinterType.network
                          ? Icons.network_wifi
                          : printer.type == AppPrinterType.bluetooth
                              ? Icons.bluetooth
                              : Icons.usb,
                      color: isConnected ? colorScheme.primary : null,
                    ),
                    title: Text(printer.name),
                    subtitle: Text(printer.address ?? 'No address'),
                    trailing: isConnected
                        ? Icon(Icons.check_circle, color: colorScheme.primary)
                        : ElevatedButton(
                            onPressed: () => _connectToPrinter(printer),
                            child: const Text('Connect'),
                          ),
                  ),
                );
              }),
            ],

            const SizedBox(height: 24),

            // Manual Network Printer
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Network Printer (Manual)',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _ipController,
                      decoration: const InputDecoration(
                        labelText: 'IP Address',
                        hintText: '192.168.1.100',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.computer),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final ip = _ipController.text.trim();
                          if (ip.isNotEmpty) {
                            final service = ref.read(thermalPrinterServiceProvider);
                            final networkPrinter = service.createNetworkPrinter(ip);
                            _connectToPrinter(networkPrinter);
                          }
                        },
                        icon: const Icon(Icons.wifi),
                        label: const Text('Connect Network Printer'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Default port: 9100 (ESC/POS standard)',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.outline),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
