import 'package:flutter/material.dart';
import 'package:flutter_blue_classic/flutter_blue_classic.dart';
import 'package:provider/provider.dart';
import '../services/bluetooth_service.dart';
import '../services/gps_service.dart';
import 'overlay_settings.dart'; // Corrected import path
import 'package:logger/logger.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  SettingsScreenState createState() => SettingsScreenState();
}

class SettingsScreenState extends State<SettingsScreen> {
  final Logger logger = Logger();
  String _unit = 'mph'; // Initialize with default value

  @override
  Widget build(BuildContext context) {
    final bluetoothService = Provider.of<BluetoothService>(context, listen: false);
    final gpsService = Provider.of<GpsService>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          // Units Category
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Units',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
          ListTile(
            title: const Text('Units'),
            subtitle: const Text('Select units for speed'),
            trailing: DropdownButton<String>(
              value: _unit,
              items: const [
                DropdownMenuItem(
                  value: 'mph',
                  child: Text('mph'),
                ),
                DropdownMenuItem(
                  value: 'km/h',
                  child: Text('km/h'),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _unit = value!;
                  // Save to settings provider or local storage
                });
              },
            ),
          ),
          const Divider(),
          // Connections Category
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Connections',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
          // Pair OBD2 Device
          ListTile(
            leading: const Icon(Icons.bluetooth, color: Colors.redAccent),
            title: const Text('Pair OBD2 Device'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              await _pairDevice(context, 'OBD2 Device', bluetoothService);
            },
          ),
          // Pair External GPS Device
          ListTile(
            leading: const Icon(Icons.gps_fixed, color: Colors.blueAccent),
            title: const Text('Pair External GPS Device'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              await _pairDevice(context, 'External GPS Device', gpsService);
            },
          ),
          const Divider(),
          // Overlay Settings
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Overlay Settings',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.settings, color: Colors.green),
            title: const Text('Customize Overlays'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              showModalBottomSheet(
                context: context,
                builder: (context) {
                  return OverlaySettings(
                    initialSettings: {
                      'Speedometer': true,
                      'Tachometer': true,
                      'Throttle Brake Indicator': true,
                    },
                    onSettingsChanged: (updatedSettings) {
                      // Handle the updated overlay settings
                    },
                  );
                },
              );
            },
          ),
          // Additional settings options can be added here
        ],
      ),
    );
  }

  // Generic pairing function
  Future<void> _pairDevice(BuildContext context, String deviceType, dynamic service) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      List<BluetoothDevice> availableDevices = [];

      if (service is BluetoothService) {
        availableDevices = await service.scanForDevices();
      } else if (service is GpsService) {
        availableDevices = await service.scanForGpsDevices();
      }

      Navigator.pop(context); // Close the loading dialog

      if (availableDevices.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No $deviceType found.')),
        );
        return;
      }

      // Show list of available devices
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('Select $deviceType'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: availableDevices.length,
                itemBuilder: (context, index) {
                  BluetoothDevice device = availableDevices[index];
                  return ListTile(
                    title: Text(device.name ?? 'Unknown Device'),
                    subtitle: Text(device.address),
                    onTap: () async {
                      Navigator.pop(context); // Close the device list dialog
                      // Show connecting dialog
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (context) => const Center(child: CircularProgressIndicator()),
                      );

                      try {
                        if (service is BluetoothService) {
                          await service.connectToDevice(device.address, context);
                        } else if (service is GpsService) {
                          await service.connectToGpsDevice(device.address, context: context);
                        }

                        Navigator.pop(context); // Close the connecting dialog

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('$deviceType paired successfully.')),
                        );
                      } catch (e) {
                        Navigator.pop(context); // Close the connecting dialog
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to pair $deviceType: $e')),
                        );
                        logger.e('Error pairing $deviceType: $e');
                      }
                    },
                  );
                },
              ),
            ),
          );
        },
      );
    } catch (e) {
      Navigator.pop(context); // Close the loading dialog if open
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error during pairing: $e')),
      );
      logger.e('Error during pairing: $e');
    }
  }
}