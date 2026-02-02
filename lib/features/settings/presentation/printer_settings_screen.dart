import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/printer_service.dart';

// Provider to hold the currently selected device (persisting this would require SharedPreferences not implemented yet)
final selectedPrinterProvider = StateProvider<BluetoothDevice?>((ref) => null);

class PrinterSettingsScreen extends ConsumerStatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  ConsumerState<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends ConsumerState<PrinterSettingsScreen> {
  List<BluetoothDevice> _devices = [];
  bool _isLoading = false;
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _scan();
  }

  Future<void> _scan() async {
    setState(() => _isLoading = true);
    final service = ref.read(printerServiceProvider);
    try {
      final devices = await service.getBondedDevices();
      setState(() => _devices = devices);
    } finally {
      setState(() => _isLoading = false);
    }
    _checkConnection();
  }

  Future<void> _checkConnection() async {
     final service = ref.read(printerServiceProvider);
     final connected = await service.isConnected;
     if (mounted) setState(() => _isConnected = connected);
  }

  Future<void> _connect(BluetoothDevice device) async {
    final service = ref.read(printerServiceProvider);
    setState(() => _isLoading = true);
    try {
      // Disconnect previous first just to be safe
      await service.disconnect();
      
      final success = await service.connect(device);
      if (success) {
        ref.read(selectedPrinterProvider.notifier).state = device;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Connected to ${device.name}')),
          );
        }
      } else {
         if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Connection failed')),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        _checkConnection();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedDevice = ref.watch(selectedPrinterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Printer Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _scan,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (selectedDevice != null)
                  Container(
                    color: _isConnected ? Colors.green.shade100 : Colors.red.shade100,
                    child: ListTile(
                      title: Text('Current Printer: ${selectedDevice.name}'),
                      subtitle: Text(_isConnected ? 'Connected' : 'Disconnected'),
                      trailing: IconButton(
                        icon: const Icon(Icons.print_disabled),
                        onPressed: () async {
                           await ref.read(printerServiceProvider).disconnect();
                           ref.read(selectedPrinterProvider.notifier).state = null;
                           _checkConnection();
                        },
                      ),
                    ),
                  ),
                const Divider(),
                Expanded(
                  child: _devices.isEmpty
                      ? const Center(child: Text('No bonded Bluetooth devices found.\nPlease pair your printer in Android Settings first.'))
                      : ListView.builder(
                          itemCount: _devices.length,
                          itemBuilder: (context, index) {
                            final device = _devices[index];
                            final isSelected = device.address == selectedDevice?.address;

                            return ListTile(
                              title: Text(device.name ?? 'Unknown Device'),
                              subtitle: Text(device.address ?? ''),
                              trailing: isSelected 
                                  ? const Icon(Icons.check_circle, color: Colors.green)
                                  : ElevatedButton(
                                      onPressed: () => _connect(device),
                                      child: const Text('Connect'),
                                    ),
                              onTap: () => _connect(device),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
