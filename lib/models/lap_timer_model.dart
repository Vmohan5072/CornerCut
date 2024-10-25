import 'package:flutter/foundation.dart';
import '../services/gps_service.dart';

class LapTimerModel with ChangeNotifier {
  String mode = 'Track';
  GpsData? startPosition;
  GpsData? endPosition;
  GpsData? lapPoint;

  void setMode(String newMode) {
    mode = newMode;
    notifyListeners();
  }

  void setStartPosition(GpsData position) {
    startPosition = position;
    notifyListeners();
  }

  void setEndPosition(GpsData position) {
    endPosition = position;
    notifyListeners();
  }

  void setLapPoint(GpsData position) {
    lapPoint = position;
    notifyListeners();
  }
}