import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:logger/logger.dart';
import '../services/bluetooth_service.dart';
import '../services/permission_service.dart';

class ObdConnectionScreen extends StatefulWidget {
  const ObdConnectionScreen({super.key});

  @override
  ObdConnectionScreenState createState() => ObdConnectionScreenState();
}

class ObdConnectionScreenState extends State<ObdConnectionScreen> {
  List<BluetoothDevice> _devices = [];
  final BluetoothService _bluetoothService = BluetoothService();
  final Logger logger = Logger();
  bool _isConnecting = false;

  @override
  void initState() {
    super.initState();
    initBluetooth();
  }

  // Initialize Bluetooth and request permission
  void initBluetooth() async {
    bool hasPermission = await PermissionService.requestBluetoothPermission();
    if (hasPermission) {
      _getBondedDevices();
    } else {
      logger.w('Bluetooth permission denied');
      // Show a SnackBar to inform the user
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bluetooth permission denied')),
      );
    }
  }

  // Get bonded Bluetooth devices
  void _getBondedDevices() async {
    try {
      List<BluetoothDevice> devices =
          await FlutterBluetoothSerial.instance.getBondedDevices();
      setState(() {
        _devices = devices;
        logger.d('Bonded devices: $_devices');
      });
    } catch (e) {
      logger.e('Error getting bonded devices: $e');
      // Show a SnackBar to inform the user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error getting devices: $e')),
      );
    }
  }

  // Connect to selected Bluetooth device
  void _connectToDevice(BluetoothDevice device) async {
    setState(() {
      _isConnecting = true;
    });
    logger.i('Connecting to device: ${device.name ?? 'Unknown Device'}');
    await _bluetoothService.connectToDevice(device.address, context);
    setState(() {
      _isConnecting = false;
    });
    // Show a SnackBar to inform the user
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Connected to ${device.name ?? 'Device'}')),
    );
  }

  @override
  void dispose() {
    _bluetoothService.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect to OBD-II Device'),
      ),
      body: _isConnecting
          ? const Center(child: CircularProgressIndicator())
          : _devices.isNotEmpty
              ? ListView.builder(
                  itemCount: _devices.length,
                  itemBuilder: (context, index) {
                    BluetoothDevice device = _devices[index];
                    return ListTile(
                      title: Text(device.name ?? 'Unknown Device'),
                      subtitle: Text(device.address),
                      onTap: () => _connectToDevice(device),
                    );
                  },
                )
              : const Center(
                  child: Text('No bonded Bluetooth devices found.'),
                ),
    );
  }
}