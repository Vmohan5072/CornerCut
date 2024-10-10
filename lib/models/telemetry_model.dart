import 'package:flutter/material.dart';

class TelemetryData {
  final double speed; // in mph
  final double rpm;
  final double throttle; // in percentage
  final double brake; // in percentage
  final double latitude;
  final double longitude;
  final double altitude;
  final DateTime timestamp;

  TelemetryData({
    required this.speed,
    required this.rpm,
    required this.throttle,
    required this.brake,
    required this.latitude,
    required this.longitude,
    required this.altitude,
    required this.timestamp,
  });
}

class TelemetryModel with ChangeNotifier {
  final List<TelemetryData> _dataPoints = [];

  List<TelemetryData> get dataPoints => _dataPoints;

  double _currentSpeed = 0.0;
  double _currentRpm = 0.0;
  double _currentThrottle = 0.0;
  double _currentBrake = 0.0;
  double _currentLatitude = 0.0;
  double _currentLongitude = 0.0;
  double _currentAltitude = 0.0;

  // Update telemetry data
  void updateTelemetry({
    double? speed,
    double? rpm,
    double? throttle,
    double? brake,
    double? latitude,
    double? longitude,
    double? altitude,
  }) {
    _currentSpeed = speed ?? _currentSpeed;
    _currentRpm = rpm ?? _currentRpm;
    _currentThrottle = throttle ?? _currentThrottle;
    _currentBrake = brake ?? _currentBrake;
    _currentLatitude = latitude ?? _currentLatitude;
    _currentLongitude = longitude ?? _currentLongitude;
    _currentAltitude = altitude ?? _currentAltitude;

    final dataPoint = TelemetryData(
      speed: _currentSpeed,
      rpm: _currentRpm,
      throttle: _currentThrottle,
      brake: _currentBrake,
      latitude: _currentLatitude,
      longitude: _currentLongitude,
      altitude: _currentAltitude,
      timestamp: DateTime.now().toUtc(),
    );
    _dataPoints.add(dataPoint);
    notifyListeners();
  }

  // Binary search to find the telemetry data closest to the target time
  TelemetryData? getTelemetryAt(DateTime targetTime) {
    if (_dataPoints.isEmpty) return null;

    int low = 0;
    int high = _dataPoints.length - 1;
    TelemetryData? closestData;

    while (low <= high) {
      int mid = (low + high) ~/ 2;
      TelemetryData midData = _dataPoints[mid];

      if (midData.timestamp.isBefore(targetTime)) {
        low = mid + 1;
        closestData = midData;
      } else if (midData.timestamp.isAfter(targetTime)) {
        high = mid - 1;
      } else {
        return midData;
      }
    }

    return closestData;
  }

  // Clear all telemetry data
  void clearTelemetry() {
    _dataPoints.clear();
    notifyListeners();
  }
}