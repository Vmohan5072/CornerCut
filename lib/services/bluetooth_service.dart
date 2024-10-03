import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'dart:typed_data';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import '../models/telemetry_model.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:intl/intl.dart';

class BluetoothService {
  BluetoothConnection? connection;
  final Logger logger = Logger();

  // Connect to the OBD-II device with address and context
  Future<void> connectToDevice(String address, BuildContext context) async {
    try {
      connection = await BluetoothConnection.toAddress(address);
      logger.i('Connected to the OBD-II device at $address');

      // Listen to incoming data
      connection!.input!.listen((Uint8List data) {
        String receivedData = String.fromCharCodes(data).trim();
        logger.d('Data received: $receivedData');

        _processReceivedData(receivedData, context);
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

  // Disconnect from the OBD-II device
  void disconnect() {
    if (connection != null) {
      connection!.close();
      logger.i('Disconnected from the OBD-II device');
      connection = null;
    }
  }

  // Send data to the OBD-II device
  void sendData(String data) {
    if (connection != null && connection!.isConnected) {
      connection!.output.add(Uint8List.fromList(data.codeUnits));
      logger.d('Data sent: $data');
    } else {
      logger.w('Attempted to send data while not connected');
    }
  }

  // Process received data and update telemetry
  void _processReceivedData(String data, BuildContext context) {
    // Example data format: "SPEED:60 RPM:3000"
    double speed = parseSpeed(data);
    double rpm = parseRPM(data);

    if (speed > 0 || rpm > 0) {
      Provider.of<TelemetryModel>(context, listen: false).updateTelemetry(speed, rpm);
      logger.i('Telemetry updated - Speed: $speed mph, RPM: $rpm');
    } else {
      logger.w('Received invalid telemetry data: $data');
    }
  }

  // Parse speed from data string and convert from km/h to mph
  double parseSpeed(String data) {
    RegExp speedRegex = RegExp(r'SPEED:(\d+(\.\d+)?)');
    Match? match = speedRegex.firstMatch(data);
    if (match != null && match.groupCount >= 1) {
      double speedInKmh = double.parse(match.group(1)!);
      return speedInKmh * 0.621371; // Convert km/h to mph
    }
    return 0.0;
  }

  // Parse RPM from data string
  double parseRPM(String data) {
    RegExp rpmRegex = RegExp(r'RPM:(\d+(\.\d+)?)');
    Match? match = rpmRegex.firstMatch(data);
    if (match != null && match.groupCount >= 1) {
      return double.parse(match.group(1)!);
    }
    return 0.0;
  }
}