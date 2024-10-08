import 'dart:async'; // For StreamSubscription
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'dart:typed_data';
import 'package:logger/logger.dart' as app_logger; // Alias to avoid naming conflicts
import 'package:provider/provider.dart';
import '../models/telemetry_model.dart';
import 'package:flutter/material.dart';

class BluetoothService {
  final FlutterReactiveBle _ble = FlutterReactiveBle();
  StreamSubscription<ConnectionStateUpdate>? _connection;
  final app_logger.Logger _logger = app_logger.Logger();

  // Connect to a BLE device by its ID
  Future<void> connectToDevice(String deviceId, BuildContext context) async {
    try {
      _logger.i('Connecting to device: $deviceId');
      _connection = _ble.connectToDevice(
        id: deviceId,
        connectionTimeout: const Duration(seconds: 10),
      ).listen((connectionState) {
        _logger.d('Connection state: ${connectionState.connectionState}');
        if (connectionState.connectionState == DeviceConnectionState.connected) {
          _logger.i('Connected to $deviceId');
          discoverServices(deviceId, context);
        } else if (connectionState.connectionState == DeviceConnectionState.disconnected) {
          _logger.w('Disconnected from $deviceId');
          // Handle disconnection if needed
        }
      }, onError: (Object error) {
        _logger.e('Connection to $deviceId failed: $error');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Connection failed: $error')),
          );
        }
      });
    } catch (e) {
      _logger.e('Error connecting to device: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error connecting to device: $e')),
        );
      }
    }
  }

  // Disconnect from the current device
  void disconnect() {
    _connection?.cancel();
    _logger.i('Disconnected from device');
  }

  // Discover services and characteristics
  Future<void> discoverServices(String deviceId, BuildContext context) async {
    try {
      List<DiscoveredService> services = await _ble.discoverServices(deviceId);
      for (var service in services) {
        for (var characteristic in service.characteristics) {
          // Create a QualifiedCharacteristic
          final qualifiedCharacteristic = QualifiedCharacteristic(
            deviceId: deviceId,
            serviceId: service.serviceId,
            characteristicId: characteristic.characteristicId,
          );

          // Subscribe to notifications if the characteristic supports it
          if (characteristic.isNotifiable) {
            _ble.subscribeToCharacteristic(qualifiedCharacteristic).listen(
              (data) {
                String receivedData = String.fromCharCodes(data).trim();
                _logger.d('Data received: $receivedData');
                _processReceivedData(receivedData, context);
              },
              onError: (error) {
                _logger.e('Error in subscription: $error');
              },
            );
          }
        }
      }
    } catch (e) {
      _logger.e('Error discovering services: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error discovering services: $e')),
        );
      }
    }
  }

  // Send data to a characteristic
  Future<void> sendData(QualifiedCharacteristic characteristic, String data) async {
    try {
      Uint8List bytes = Uint8List.fromList(data.codeUnits);
      await _ble.writeCharacteristicWithResponse(characteristic, value: bytes);
      _logger.d('Data sent: $data');
    } catch (e) {
      _logger.e('Error sending data: $e');
    }
  }

  // Process received data and update telemetry
  void _processReceivedData(String data, BuildContext context) {
    try {
      // Example data format: "SPEED:60 RPM:3000 THROTTLE:45 BRAKE:0"
      double speed = parseSpeed(data);
      double rpm = parseRPM(data);
      double throttle = parseThrottle(data);
      double brake = parseBrake(data);

      if (speed >= 0 && rpm >= 0 && throttle >= 0 && brake >= 0) {
        Provider.of<TelemetryModel>(context, listen: false).updateTelemetry(
          speed: speed,
          rpm: rpm,
          throttle: throttle,
          brake: brake,
        );
        _logger.i(
            'Telemetry updated - Speed: $speed mph, RPM: $rpm, Throttle: $throttle%, Brake: $brake%');
      } else {
        _logger.w('Received invalid telemetry data: $data');
      }
    } catch (e) {
      _logger.e('Error processing data: $e');
    }
  }

  // Parsing functions
  double parseSpeed(String data) {
    RegExp speedRegex = RegExp(r'SPEED:(\d+(\.\d+)?)');
    Match? match = speedRegex.firstMatch(data);
    if (match != null && match.groupCount >= 1) {
      double speedInKmh = double.parse(match.group(1)!);
      return speedInKmh * 0.621371; // Convert km/h to mph
    }
    return -1.0;
  }

  double parseRPM(String data) {
    RegExp rpmRegex = RegExp(r'RPM:(\d+(\.\d+)?)');
    Match? match = rpmRegex.firstMatch(data);
    if (match != null && match.groupCount >= 1) {
      return double.parse(match.group(1)!);
    }
    return -1.0;
  }

  double parseThrottle(String data) {
    RegExp throttleRegex = RegExp(r'THROTTLE:(\d+(\.\d+)?)');
    Match? match = throttleRegex.firstMatch(data);
    if (match != null && match.groupCount >= 1) {
      return double.parse(match.group(1)!);
    }
    return -1.0;
  }

  double parseBrake(String data) {
    RegExp brakeRegex = RegExp(r'BRAKE:(\d+(\.\d+)?)');
    Match? match = brakeRegex.firstMatch(data);
    if (match != null && match.groupCount >= 1) {
      return double.parse(match.group(1)!);
    }
    return -1.0;
  }
}