import 'dart:async';
import 'dart:convert';
import 'dart:typed_data'; // Import for Uint8List
import 'package:flutter_blue_classic/flutter_blue_classic.dart';
import 'package:logger/logger.dart' as app_logger;
import 'package:provider/provider.dart';
import '../models/telemetry_model.dart';
import 'package:flutter/material.dart';

class BluetoothService {
  final FlutterBlueClassic _flutterBlue = FlutterBlueClassic();
  final app_logger.Logger _logger = app_logger.Logger();

  StreamSubscription<BluetoothAdapterState>? _stateSubscription; // Adjusted type
  StreamSubscription<BluetoothDevice>? _scanSubscription; // Adjusted type
  BluetoothConnection? _connection;
  StreamSubscription<Uint8List>? _readSubscription;
  Timer? _obdTimer;

  // Start scanning for devices
  void startScan() {
    _flutterBlue.startScan();

    _stateSubscription = _flutterBlue.adapterState.listen((state) {
      _logger.i('Bluetooth Adapter State: $state');
      if (state == BluetoothAdapterState.off) {
        _logger.w('Bluetooth is turned off.');
      }
    });
  }

  // Stop scanning
  void stopScan() {
    _flutterBlue.stopScan();
    _scanSubscription?.cancel();
    _scanSubscription = null;
  }

  // Connect to a device and start communication
  Future<void> connectToDevice(String deviceAddress, BuildContext context) async {
    try {
      _logger.i('Connecting to device: $deviceAddress');
      _connection = await _flutterBlue.connect(deviceAddress);
      _logger.i('Connected to device with address: $deviceAddress');

      // Listen to incoming data
      _readSubscription = _connection?.input?.listen((data) {
        String response = utf8.decode(data);
        _logger.d('Data received: $response');
        _processObdResponse(response, context);
      }, onDone: () {
        _logger.w('Disconnected from device with address: $deviceAddress');
        _connection = null;
      }, onError: (error) {
        _logger.e('Error in connection: $error');
        _connection = null;
      });

      // Initialize OBD communication
      _initializeObd();
    } catch (e) {
      _logger.e('Error connecting to device: $e');
    }
  }

  // Initialize OBD communication by sending necessary commands
  void _initializeObd() {
    // Reset device
    sendData('ATZ\r');
    Future.delayed(Duration(seconds: 2));

    // Set protocol to automatic
    sendData('ATSP0\r');
    Future.delayed(Duration(milliseconds: 500));

    // Turn off echo
    sendData('ATE0\r');
    Future.delayed(Duration(milliseconds: 500));

    // Now ready to send OBD-II commands
    // Example: Request vehicle data every second
    _obdTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      sendData('010D\r'); // PID for vehicle speed
      sendData('010C\r'); // PID for RPM
      sendData('0111\r'); // PID for Throttle Position
      sendData('015A\r'); // PID for Brake Input Status (may not be supported)
    });
  }

  // Send data to the connected device
  void sendData(String data) {
    if (_connection != null && _connection!.isConnected) {
      _connection!.output.add(utf8.encode(data));
      _logger.i('Sent data: $data');
    } else {
      _logger.w('No device connected.');
    }
  }

  // Process OBD responses
  void _processObdResponse(String response, BuildContext context) {
    // Clean up the response
    response = response.replaceAll('\r', '').replaceAll('\n', '').trim();

    // Split multiple responses
    List<String> responses = response.split('>');
    for (String res in responses) {
      if (res.isNotEmpty) {
        _parseObdData(res, context);
      }
    }
  }

  // Parse OBD data and update telemetry
  void _parseObdData(String data, BuildContext context) {
    try {
      // Check if data starts with '41' which indicates a response to a request
      if (data.startsWith('41')) {
        // Remove spaces
        String cleanData = data.replaceAll(' ', '');
        // Extract the PID
        String pid = cleanData.substring(2, 4);
        if (pid == '0D') {
          // Vehicle speed
          String speedHex = cleanData.substring(4, 6);
          int speedKmh = int.parse(speedHex, radix: 16);
          double speedMph = speedKmh * 0.621371;

          Provider.of<TelemetryModel>(context, listen: false).updateTelemetry(
            speed: speedMph,
          );
          _logger.i('Speed updated: $speedMph mph');
        } else if (pid == '0C') {
          // RPM
          String rpmHex = cleanData.substring(4, 8);
          int rpm = int.parse(rpmHex, radix: 16) ~/ 4;

          Provider.of<TelemetryModel>(context, listen: false).updateTelemetry(
            rpm: rpm.toDouble(),
          );
          _logger.i('RPM updated: $rpm');
        } else if (pid == '11') {
          // Throttle Position
          String throttleHex = cleanData.substring(4, 6);
          int throttle = int.parse(throttleHex, radix: 16) * 100 ~/ 255;

          Provider.of<TelemetryModel>(context, listen: false).updateTelemetry(
            throttle: throttle.toDouble(),
          );
          _logger.i('Throttle updated: $throttle%');
        } else if (pid == '5A') {
          // Brake Input Status (may vary by vehicle)
          String brakeHex = cleanData.substring(4, 6);
          int brakeStatus = int.parse(brakeHex, radix: 16);
          double brake = brakeStatus == 0 ? 0.0 : 100.0;

          Provider.of<TelemetryModel>(context, listen: false).updateTelemetry(
            brake: brake,
          );
          _logger.i('Brake updated: $brake%');
        } else {
          _logger.w('Unhandled OBD data: $data');
        }
      }
    } catch (e) {
      _logger.e('Error parsing OBD data: $e');
    }
  }

  // Disconnect from the OBD device
  void disconnect() {
    _readSubscription?.cancel();
    _connection?.finish(); // Use finish() to close the connection
    _connection = null;
    _obdTimer?.cancel();
    _logger.i('Disconnected from OBD device');
  }

  // Dispose resources
  void dispose() {
    disconnect();
    _stateSubscription?.cancel();
    _scanSubscription?.cancel();
  }
}