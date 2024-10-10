import 'dart:async';
import 'dart:convert';
import 'dart:typed_data'; // Import for Uint8List
import 'package:flutter_blue_classic/flutter_blue_classic.dart';
import 'package:nmea/nmea.dart';
import 'package:logger/logger.dart' as app_logger;

/// A data class to hold GPS information.
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

/// Service to handle GPS data from GPS module using Bluetooth Classic and NMEA parsing.
class GpsService {
  final app_logger.Logger _logger = app_logger.Logger();
  final FlutterBlueClassic _flutterBlue = FlutterBlueClassic();
  BluetoothConnection? _connection;
  final StreamController<GpsData> _gpsDataController = StreamController.broadcast();
  String _nmeaBuffer = '';

  /// Exposes a stream of [GpsData] for other parts of the app to listen to.
  Stream<GpsData> get gpsDataStream => _gpsDataController.stream;

  /// NMEA Decoder instance with registered sentence types.
  final NmeaDecoder _nmeaDecoder = NmeaDecoder(onlyAllowValid: true)
    ..registerTalkerSentence('GGA', (line) => GgaSentence(raw: line))
    ..registerTalkerSentence('RMC', (line) => RmcSentence(raw: line));

  /// Initializes the GPS service by enabling Bluetooth and connecting to GPS module.
  Future<void> initialize() async {
    try {
      // Check if Bluetooth is supported.
      bool isSupported = await _flutterBlue.isSupported;
      if (!isSupported) {
        _logger.e('Bluetooth is not supported on this device.');
        return;
      }

      // Check if Bluetooth is enabled.
      bool isEnabled = await _flutterBlue.isEnabled;
      if (!isEnabled) {
        _flutterBlue.turnOn(); // Removed assignment
        _logger.i('Bluetooth turned on.');
      }

      _logger.i('Starting discovery for GPS module.');
      // Start discovering Bluetooth devices.
      _flutterBlue.startScan();

      _flutterBlue.scanResults.listen((device) async { // Changed parameter to single device
        if (device.name!.isNotEmpty && (device.name == 'Garmin GLO' || device.name!.contains('GPS'))) {
          _logger.i('GPS module found. Attempting to connect to ${device.address}.');
          _flutterBlue.stopScan();

          // Attempt to establish a Bluetooth connection.
          _connection = await _flutterBlue.connect(device.address);
          _logger.i('Connected to GPS module at ${device.address}.');
          _listenToNmeaData();
        }
      });
    } catch (e) {
      _logger.e('Error initializing GPS Service: $e');
    }
  }

  /// Listens to incoming NMEA data from the GPS module.
  void _listenToNmeaData() {
    _connection?.input?.listen(
      (Uint8List data) {
        String nmeaSentence = utf8.decode(data);

        // Buffer incoming data to handle incomplete NMEA sentences.
        _nmeaBuffer += nmeaSentence;

        // Split the buffer into individual sentences.
        List<String> sentences = _nmeaBuffer.split('\r\n');
        _nmeaBuffer = sentences.removeLast();

        for (String sentence in sentences) {
          if (sentence.isNotEmpty) {
            _processNmeaSentence(sentence);
          }
        }
      },
      onDone: () {
        _logger.i('Disconnected from GPS module.');
        _connection = null;
      },
      onError: (error) {
        _logger.e('Error while listening to GPS module: $error');
      },
    );
  }

  /// Processes a single NMEA sentence.
  void _processNmeaSentence(String sentence) {
    try {
      // Decode the NMEA sentence.
      final NmeaSentence? nmeaSentence = _nmeaDecoder.decode(sentence);
      if (nmeaSentence == null) {
        _logger.w('Failed to decode NMEA sentence: $sentence');
        return;
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
          _logger.d('GPS Data updated: $gpsData');
        }
      } else if (nmeaSentence is RmcSentence) {
        double? latitude = nmeaSentence.latitude;
        double? longitude = nmeaSentence.longitude;
        DateTime? timestamp = _parseDateTime(nmeaSentence.date, nmeaSentence.time);

        if (latitude != null && longitude != null && timestamp != null) {
          GpsData gpsData = GpsData(
            latitude: latitude,
            longitude: longitude,
            altitude: 0.0, // RMC does not provide altitude.
            timestamp: timestamp,
          );
          _gpsDataController.add(gpsData);
          _logger.d('GPS Data updated: $gpsData');
        }
      }
      // Additional sentence types can be handled here if needed.
    } catch (e) {
      _logger.e('Error parsing NMEA sentence: $e');
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
    _connection?.finish(); // Use finish() to close the connection
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
  String get status => fields[2]; // 'A' = active, 'V' = void
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