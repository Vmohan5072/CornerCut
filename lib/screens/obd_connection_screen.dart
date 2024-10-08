import 'dart:async'; // For StreamSubscription
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:logger/logger.dart' as app_logger; // Alias to avoid naming conflicts
import '../services/bluetooth_service.dart';
import '../services/permission_service.dart';

class ObdConnectionScreen extends StatefulWidget {
  const ObdConnectionScreen({Key? key}) : super(key: key);

  @override
  ObdConnectionScreenState createState() => ObdConnectionScreenState();
}

class ObdConnectionScreenState extends State<ObdConnectionScreen> {
  final BluetoothService _bluetoothService = BluetoothService();
  final app_logger.Logger logger = app_logger.Logger();
  bool _isScanning = false;
  List<DiscoveredDevice> _devices = [];
  final FlutterReactiveBle _ble = FlutterReactiveBle();
  StreamSubscription<DiscoveredDevice>? _scanSubscription;

  @override
  void initState() {
    super.initState();
    initBluetooth();
  }

  // Initialize Bluetooth and request permissions
  void initBluetooth() async {
    bool hasPermission = await PermissionService.requestPermissions();
    if (hasPermission) {
      _startScan();
    } else {
      logger.w('Bluetooth or Location permission denied');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bluetooth or Location permission denied')),
        );
      }
    }
  }

  // Start scanning for BLE devices
  void _startScan() {
    setState(() {
      _isScanning = true;
      _devices.clear();
    });

    _scanSubscription = _ble.scanForDevices(
      withServices: [], // Specify service UUIDs if known for faster scanning
      scanMode: ScanMode.lowLatency,
    ).listen((device) {
      // Avoid duplicates
      if (!_devices.any((d) => d.id == device.id)) {
        setState(() {
          _devices.add(device);
          logger.d('Device found: ${device.name}');
        });
      }
    }, onError: (error) {
      logger.e('Scan error: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scan error: $error')),
        );
      }
    });

    // Stop scanning after a duration
    Future.delayed(const Duration(seconds: 10), () {
      _stopScan();
    });
  }

  // Stop scanning
  void _stopScan() {
    _scanSubscription?.cancel();
    setState(() {
      _isScanning = false;
    });
    logger.i('Scanning stopped');
  }

  // Connect to selected BLE device
  void _connectToDevice(DiscoveredDevice device) async {
    _stopScan(); // Ensure scanning is stopped
    logger.i('Connecting to device: ${device.name}');
    await _bluetoothService.connectToDevice(device.id, context);
    // Show a SnackBar to inform the user
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connected to ${device.name.isNotEmpty ? device.name : 'Device'}')),
      );
      // Navigate to Telemetry Display Screen
      Navigator.pushNamed(context, '/telemetry');
    }
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _bluetoothService.disconnect();
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
                    DiscoveredDevice device = _devices[index];
                    return ListTile(
                      title: Text(device.name.isNotEmpty ? device.name : 'Unknown Device'),
                      subtitle: Text(device.id),
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