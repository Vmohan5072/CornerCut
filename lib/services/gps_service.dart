import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_blue_classic/flutter_blue_classic.dart';
import 'package:nmea/nmea.dart';
import 'package:logger/logger.dart' as app_logger;

// Make sure GpsData is publicly accessible
class GpsData {
  final double latitude;
  final double longitude;
  final double altitude;
  final DateTime timestamp;

  GpsData({
    required this.latitude,
    required this.longitude,
    required this.altitude,
    required this.timestamp,
  });

  @override
  String toString() {
    return 'Latitude: $latitude, Longitude: $longitude, Altitude: $altitude, Timestamp: $timestamp';
  }
}

class GpsService {
  final app_logger.Logger _logger = app_logger.Logger();
  final FlutterBlueClassic _flutterBlue = FlutterBlueClassic();
  BluetoothConnection? _connection;
  final StreamController<GpsData> _gpsDataController = StreamController.broadcast();
  String _nmeaBuffer = '';

  StreamSubscription<Uint8List>? _readSubscription;

  Stream<GpsData> get gpsDataStream => _gpsDataController.stream;

  final NmeaDecoder _nmeaDecoder = NmeaDecoder(onlyAllowValid: true)
    ..registerTalkerSentence('GGA', (line) => GgaSentence(raw: line))
    ..registerTalkerSentence('RMC', (line) => RmcSentence(raw: line));

  Future<void> initialize() async {
    try {
      bool isSupported = await _flutterBlue.isSupported;
      if (!isSupported) {
        _logger.e('Bluetooth is not supported on this device.');
        return;
      }

      bool isEnabled = await _flutterBlue.isEnabled;
      if (!isEnabled) {
        _flutterBlue.turnOn();
        _logger.i('Bluetooth turned on.');
      }

      _logger.i('Starting discovery for GPS module.');
      List<BluetoothDevice> devices = await scanForGpsDevices();

      if (devices.isNotEmpty) {
        BluetoothDevice gpsDevice = devices.first;
        _logger.i('GPS module found: ${gpsDevice.name} [${gpsDevice.address}]. Attempting to connect.');
        await connectToGpsDevice(gpsDevice.address);
      } else {
        _logger.w('No GPS module found.');
      }
    } catch (e) {
      _logger.e('Error initializing GPS Service: $e');
    }
  }

  Future<List<BluetoothDevice>> scanForGpsDevices({Duration timeout = const Duration(seconds: 5)}) async {
    List<BluetoothDevice> gpsDevices = [];
    Completer<List<BluetoothDevice>> completer = Completer();

    try {
      _logger.i('Starting Bluetooth scan for GPS devices.');
      _flutterBlue.startScan();

      StreamSubscription<BluetoothDevice>? scanSubscription;

      scanSubscription = _flutterBlue.scanResults.listen((BluetoothDevice device) {
        if (device.name != null &&
            device.name!.isNotEmpty &&
            (device.name!.toLowerCase().contains('gps') || device.name!.toLowerCase().contains('garmin'))) {
          if (!gpsDevices.contains(device)) {
            gpsDevices.add(device);
            _logger.i('Found GPS device: ${device.name} [${device.address}]');
          }
        }
      });

      await Future.delayed(timeout);
      _flutterBlue.stopScan();
      scanSubscription?.cancel();

      _logger.i('Bluetooth scan completed. Found ${gpsDevices.length} GPS devices.');
      completer.complete(gpsDevices);
    } catch (e) {
      _logger.e('Error during GPS Bluetooth scanning: $e');
      completer.completeError(e);
    }

    return completer.future;
  }

  // Connect to GPS device and start listening to data
  Future<void> connectToGpsDevice(String deviceAddress) async {
    try {
      _logger.i('Connecting to GPS device: $deviceAddress');
      _connection = await _flutterBlue.connect(deviceAddress);
      _logger.i('Connected to GPS device with address: $deviceAddress');

      // Listen to incoming data
      _readSubscription = _connection?.input?.listen((data) {
        String response = utf8.decode(data);
        _logger.d('GPS Data received: $response');
        _processNmeaSentence(response);
      }, onDone: () {
        _logger.w('Disconnected from GPS device with address: $deviceAddress');
        _connection = null;
      }, onError: (error) {
        _logger.e('Error in GPS connection: $error');
        _connection = null;
      });

      // Initialize GPS communication if necessary
      _initializeGps();
    } catch (e) {
      _logger.e('Error connecting to GPS device: $e');
      throw e; // Propagate the error to handle it in the UI
    }
  }

  // Initialize GPS communication
  void _initializeGps() {
    // Example: Send initialization commands if required by GPS device
    sendData('INIT_COMMAND\r');
    Future.delayed(const Duration(seconds: 2));

    // Start periodic data requests if needed
    // For many GPS devices, data is sent automatically, so this might not be necessary
  }

  // Send data to the connected GPS device
  void sendData(String data) {
    if (_connection != null && _connection!.isConnected) {
      _connection!.output.add(utf8.encode(data));
      _logger.i('Sent GPS data: $data');
    } else {
      _logger.w('No GPS device connected.');
    }
  }

  // Process incoming NMEA sentence
  void _processNmeaSentence(String sentence) {
    try {
      // Buffer incoming data to handle incomplete sentences
      _nmeaBuffer += sentence;

      // Split buffer into individual sentences
      List<String> sentences = _nmeaBuffer.split('\r\n');
      _nmeaBuffer = sentences.removeLast(); // Keep incomplete sentence in buffer

      for (String s in sentences) {
        if (s.isNotEmpty) {
          // Decode the NMEA sentence
          final NmeaSentence? nmeaSentence = _nmeaDecoder.decode(s);
          if (nmeaSentence == null) {
            _logger.w('Failed to decode NMEA sentence: $s');
            continue;
          }

          if (nmeaSentence is GgaSentence) {
            double? latitude = nmeaSentence.latitude;
            double? longitude = nmeaSentence.longitude;
            double? altitude = nmeaSentence.altitude;

            if (latitude != null && longitude != null) {
              GpsData gpsData = GpsData(
                latitude: latitude,
                longitude: longitude,
                altitude: altitude ?? 0.0,
                timestamp: DateTime.now().toUtc(),
              );
              _gpsDataController.add(gpsData);
              _logger.i('GPS Data updated: $gpsData');
            }
          } else if (nmeaSentence is RmcSentence) {
            double? latitude = nmeaSentence.latitude;
            double? longitude = nmeaSentence.longitude;
            DateTime? timestamp = _parseDateTime(nmeaSentence.date, nmeaSentence.time);

            if (latitude != null && longitude != null && timestamp != null) {
              GpsData gpsData = GpsData(
                latitude: latitude,
                longitude: longitude,
                altitude: 0.0, // Altitude not available in RMC
                timestamp: timestamp,
              );
              _gpsDataController.add(gpsData);
              _logger.i('GPS Data updated: $gpsData');
            }
          }
        }
      }
    } catch (e) {
      _logger.e('Error processing NMEA sentence: $e');
    }
  }

  /// Parses date and time from RMC sentence fields.
  DateTime? _parseDateTime(String date, String time) {
    try {
      // Date format: DDMMYY
      int day = int.parse(date.substring(0, 2));
      int month = int.parse(date.substring(2, 4));
      int year = int.parse(date.substring(4, 6)) + 2000;

      // Time format: HHMMSS
      int hour = int.parse(time.substring(0, 2));
      int minute = int.parse(time.substring(2, 4));
      int second = int.parse(time.substring(4, 6));

      return DateTime.utc(year, month, day, hour, minute, second);
    } catch (e) {
      _logger.e('Error parsing date and time: $e');
      return null;
    }
  }

  /// Disposes resources when no longer needed.
  void dispose() {
    _gpsDataController.close();
    _connection?.finish(); // Close the connection
    _readSubscription?.cancel();
    // Removed undefined variable _obdTimer
  }
}

/// Custom GGA Sentence for parsing GGA NMEA sentences.
class GgaSentence extends TalkerSentence {
  GgaSentence({required super.raw});

  String get time => fields[1];
  double? get latitude => _parseLatitude(fields[2], fields[3]);
  double? get longitude => _parseLongitude(fields[4], fields[5]);
  double? get altitude => double.tryParse(fields[9]);

  @override
  bool get valid => super.valid && fields.length >= 10;

  /// Parses latitude from NMEA format to decimal degrees.
  double? _parseLatitude(String value, String hemisphere) {
    if (value.isEmpty) return null;
    double degrees = double.parse(value.substring(0, 2));
    double minutes = double.parse(value.substring(2));
    double latitude = degrees + minutes / 60;
    return hemisphere == 'S' ? -latitude : latitude;
  }

  /// Parses longitude from NMEA format to decimal degrees.
  double? _parseLongitude(String value, String hemisphere) {
    if (value.isEmpty) return null;
    double degrees = double.parse(value.substring(0, 3));
    double minutes = double.parse(value.substring(3));
    double longitude = degrees + minutes / 60;
    return hemisphere == 'W' ? -longitude : longitude;
  }
}

/// Custom RMC Sentence for parsing RMC NMEA sentences.
class RmcSentence extends TalkerSentence {
  RmcSentence({required super.raw});

  String get time => fields[1];
  String get status => fields[2]; // A=active, V=void
  double? get latitude => _parseLatitude(fields[3], fields[4]);
  double? get longitude => _parseLongitude(fields[5], fields[6]);
  String get date => fields[9];

  @override
  bool get valid => super.valid && fields.length >= 10;

  /// Parses latitude from NMEA format to decimal degrees.
  double? _parseLatitude(String value, String hemisphere) {
    if (value.isEmpty) return null;
    double degrees = double.parse(value.substring(0, 2));
    double minutes = double.parse(value.substring(2));
    double latitude = degrees + minutes / 60;
    return hemisphere == 'S' ? -latitude : latitude;
  }

  /// Parses longitude from NMEA format to decimal degrees.
  double? _parseLongitude(String value, String hemisphere) {
    if (value.isEmpty) return null;
    double degrees = double.parse(value.substring(0, 3));
    double minutes = double.parse(value.substring(3));
    double longitude = degrees + minutes / 60;
    return hemisphere == 'W' ? -longitude : longitude;
  }
}