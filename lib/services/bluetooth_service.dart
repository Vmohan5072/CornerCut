import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'dart:typed_data';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import '../models/telemetry_model.dart';
import 'package:flutter/material.dart';
import 'dart:io';

class BluetoothService {
  BluetoothConnection? connection;
  final Logger logger = Logger();

  Future<void> connectToDevice(String address, BuildContext context) async {
    try {
      connection = await BluetoothConnection.toAddress(address);
      logger.i('Connected to the OBD-II device');
      connection!.input!.listen((Uint8List data) {
        String receivedData = String.fromCharCodes(data);
        logger.d('Data received: $receivedData');

        // Example: Parse the receivedData to extract speed and rpm
        double speed = parseSpeed(receivedData);
        double rpm = parseRPM(receivedData);

        // Update the TelemetryModel
        Provider.of<TelemetryModel>(context, listen: false).updateTelemetry(speed, rpm);
      }).onDone(() {
        logger.w('OBD-II device disconnected');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('OBD-II device disconnected')),
        );
      });
    } catch (e) {
      logger.e('Error connecting to OBD-II device: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error connecting to device: $e')),
      );
    }
  }

  void disconnect() {
    connection?.close();
    connection = null;
    logger.i('Disconnected from the OBD-II device');
  }

  void sendData(String data) {
    connection?.output.add(Uint8List.fromList(data.codeUnits));
    logger.d('Data sent: $data');
  }

  // Parse speed from OBD-II data and convert from km/h to mph
  double parseSpeed(String data) {
    RegExp speedRegex = RegExp(r'SPEED:(\d+)');
    Match? match = speedRegex.firstMatch(data);
    if (match != null && match.groupCount >= 1) {
      double speedInKmh = double.parse(match.group(1)!);
      return speedInKmh * 0.621371; // Convert km/h to mph
    }
    return 0.0;
  }

  double parseRPM(String data) {
    RegExp rpmRegex = RegExp(r'RPM:(\d+)');
    Match? match = rpmRegex.firstMatch(data);
    if (match != null && match.groupCount >= 1) {
      return double.parse(match.group(1)!);
    }
    return 0.0;
  }
}