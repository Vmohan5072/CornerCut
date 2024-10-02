import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import '../services/bluetooth_service.dart';
import '../services/permission_service.dart';

class ObdConnectionScreen extends StatefulWidget {
  @override
  _ObdConnectionScreenState createState() => _ObdConnectionScreenState();
}

class _ObdConnectionScreenState extends State<ObdConnectionScreen> {
  List<BluetoothDevice> _devices = [];
  final BluetoothService _bluetoothService = BluetoothService();

  @override
  void initState() {
    super.initState();
    initBluetooth();
  }

  void initBluetooth() async {
    bool hasPermission = await PermissionService.requestBluetoothPermission();
    if (hasPermission) {
      _getBondedDevices();
    } else {
      print('Bluetooth permission denied');
    }
  }

  void _getBondedDevices() async {
    try {
      List<BluetoothDevice> devices = await FlutterBluetoothSerial.instance.getBondedDevices();
      setState(() {
        _devices = devices;
      });
    } catch (e) {
      print('Error getting bonded devices: $e');
    }
  }

  void _connectToDevice(BluetoothDevice device) async {
    await _bluetoothService.connectToDevice(device.address);
    // Handle connection success or failure
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
          title: Text('Connect to OBD-II Device'),
        ),
        body: ListView(
          children: _devices
              .map((device) => ListTile(
                    title: Text(device.name ?? 'Unknown Device'),
                    subtitle: Text(device.address),
                    onTap: () => _connectToDevice(device),
                  ))
              .toList(),
        ));
  }
}