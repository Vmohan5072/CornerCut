import 'package:flutter/material.dart';

class TelemetryData {
  final double speed; // in mph
  final double rpm;
  final DateTime timestamp;

  TelemetryData({
    required this.speed,
    required this.rpm,
    required this.timestamp,
  });
}

class TelemetryModel with ChangeNotifier {
  final List<TelemetryData> _dataPoints = [];

  List<TelemetryData> get dataPoints => _dataPoints;

  void updateTelemetry(double speed, double rpm) {
    final dataPoint = TelemetryData(
      speed: speed,
      rpm: rpm,
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