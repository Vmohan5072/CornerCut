import 'package:flutter/material.dart';

class LapModel with ChangeNotifier {
  final List<Duration> _lapTimes = [];

  Duration? get bestLapTime {
    if (_lapTimes.isEmpty) return null;
    return _lapTimes.reduce((a, b) => a < b ? a : b);
  }

  Duration? get currentLapTime {
    if (_lapTimes.isEmpty) return null;
    return _lapTimes.last;
  }

  Duration? get previousLapTime {
    if (_lapTimes.length < 2) return null;
    return _lapTimes[_lapTimes.length - 2];
  }

  List<Duration> get lapTimes => _lapTimes;

  void addLapTime(Duration lapTime) {
    _lapTimes.add(lapTime);
    notifyListeners();
  }

  void resetLapTimes() {
    _lapTimes.clear();
    notifyListeners();
  }
}