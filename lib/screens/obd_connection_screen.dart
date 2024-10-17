import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_classic/flutter_blue_classic.dart';
import 'package:logger/logger.dart' as app_logger;
import '../services/bluetooth_service.dart';

class ObdConnectionScreen extends StatefulWidget {
  const ObdConnectionScreen({super.key});

  @override
  ObdConnectionScreenState createState() => ObdConnectionScreenState();
}

class ObdConnectionScreenState extends State<ObdConnectionScreen> {
  final BluetoothService _bluetoothService = BluetoothService();
  final app_logger.Logger logger = app_logger.Logger();
  final FlutterBlueClassic _flutterBlue = FlutterBlueClassic();
  bool _isScanning = false;
  List<BluetoothDevice> _devices = [];
  StreamSubscription<BluetoothDevice>? _scanSubscription;

  @override
  void initState() {
    super.initState();
    initBluetooth();
  }

  // Initialize Bluetooth and start scanning
  void initBluetooth() {
    _startScan();
  }

  // Start scanning for devices
  void _startScan() {
    setState(() {
      _isScanning = true;
      _devices.clear();
    });

    _flutterBlue.startScan();

    // Listen to bluetooth devices
    _scanSubscription = _flutterBlue.scanResults.listen((device) {
      setState(() {
        if (!_devices.any((d) => d.address == device.address)) {
          _devices.add(device);
        }
      });
    });

    // Scan times out after 10 seconds
    Future.delayed(const Duration(seconds: 10), () {
      _stopScan();
    });
  }

  // Stop scanning
  void _stopScan() {
    _flutterBlue.stopScan();
    _scanSubscription?.cancel();
    setState(() {
      _isScanning = false;
    });
    logger.i('Scanning stopped');
  }

  // Connect to selected device
  void _connectToDevice(BluetoothDevice device) async {
    _stopScan();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    try {
      await _bluetoothService.connectToDevice(device.address, context);
      Navigator.pop(context); // Close the progress dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connected to ${device.name ?? 'Device'}')),
      );
      Navigator.pop(context);
    } catch (e) {
      Navigator.pop(context); // Close the progress dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to connect: $e')),
      );
    }
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _bluetoothService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect to OBD-II Device'),
        actions: [
          IconButton(
            icon: Icon(_isScanning ? Icons.stop : Icons.search),
            onPressed: _isScanning ? _stopScan : _startScan,
            tooltip: _isScanning ? 'Stop Scan' : 'Scan for Devices',
          ),
        ],
      ),
      body: _isScanning
          ? const Center(child: CircularProgressIndicator())
          : _devices.isNotEmpty
              ? ListView.builder(
                  itemCount: _devices.length,
                  itemBuilder: (context, index) {
                    BluetoothDevice device = _devices[index];
                    String deviceName = (device.name?.isNotEmpty ?? false) ? device.name! : 'Unknown Device';
                    return ListTile(
                      leading: const Icon(Icons.bluetooth),
                      title: Text(deviceName),
                      subtitle: Text(device.address),
                      onTap: () => _connectToDevice(device),
                    );
                  },
                )
              : const Center(
                  child: Text('No Bluetooth devices found.'),
                ),
    );
  }
}