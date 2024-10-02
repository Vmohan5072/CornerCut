import 'package:flutter/material.dart';

class TelemetryModel with ChangeNotifier {
  double _speed = 0.0; // in mph
  double _rpm = 0.0;   // in RPM

  double get speed => _speed;
  double get rpm => _rpm;

  void updateTelemetry(double speed, double rpm) {
    _speed = speed;
    _rpm = rpm;
    notifyListeners();
  }
}