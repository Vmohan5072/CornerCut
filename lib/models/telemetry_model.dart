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

  Map<String, dynamic> toMap() {
    return {
      'speed': speed,
      'rpm': rpm,
      'throttle': throttle,
      'brake': brake,
      'latitude': latitude,
      'longitude': longitude,
      'altitude': altitude,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

class TelemetryModel with ChangeNotifier {
  final List<TelemetryData> _dataPoints = [];

  List<TelemetryData> get dataPoints => _dataPoints;

  TelemetryData? get latestData => _dataPoints.isNotEmpty ? _dataPoints.last : null;

  double get currentSpeed => latestData?.speed ?? 0.0;
  double get currentRpm => latestData?.rpm ?? 0.0;
  double get currentThrottle => latestData?.throttle ?? 0.0;
  double get currentBrake => latestData?.brake ?? 0.0;

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
    final dataPoint = TelemetryData(
      speed: speed ?? currentSpeed,
      rpm: rpm ?? currentRpm,
      throttle: throttle ?? currentThrottle,
      brake: brake ?? currentBrake,
      latitude: latitude ?? latestData?.latitude ?? 0.0,
      longitude: longitude ?? latestData?.longitude ?? 0.0,
      altitude: altitude ?? latestData?.altitude ?? 0.0,
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