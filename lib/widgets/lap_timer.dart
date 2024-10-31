import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math'; // For trigonometric functions
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import '../models/lap_model.dart';
import '../models/lap_timer_model.dart';
import '../services/gps_service.dart';

class LapTimer extends StatefulWidget {
  final bool isLandscape;
  const LapTimer({super.key, required this.isLandscape});

  @override
  LapTimerState createState() => LapTimerState();
}

class LapTimerState extends State<LapTimer> {
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;
  final Logger logger = Logger();

  StreamSubscription<GpsData>? _gpsSubscription;
  GpsData? _currentPosition;

  @override
  void initState() {
    super.initState();
    _subscribeToGpsData();
  }

  void _subscribeToGpsData() {
    final gpsService = Provider.of<GpsService>(context, listen: false);
    _gpsSubscription = gpsService.gpsDataStream.listen((GpsData gpsData) {
      _currentPosition = gpsData;
      final lapTimerModel = Provider.of<LapTimerModel>(context, listen: false);
      final mode = lapTimerModel.mode;

      if (mode == 'Autocross') {
        _checkAutocrossPositions(lapTimerModel);
      } else {
        _checkTrackPosition(lapTimerModel);
      }
    });
  }

  void _checkTrackPosition(LapTimerModel lapTimerModel) {
    if (lapTimerModel.lapPoint == null || _currentPosition == null) return;

    double distance = _calculateDistance(_currentPosition!, lapTimerModel.lapPoint!);
    if (distance <= 10.0) {
      if (_stopwatch.isRunning) {
        _recordLap();
      } else {
        _startStopwatch();
      }
    }
  }

  void _checkAutocrossPositions(LapTimerModel lapTimerModel) {
    if (lapTimerModel.startPosition == null || lapTimerModel.endPosition == null || _currentPosition == null) return;

    if (!_stopwatch.isRunning) {
      double startDistance = _calculateDistance(_currentPosition!, lapTimerModel.startPosition!);
      if (startDistance <= 10.0) {
        _startStopwatch();
      }
    } else {
      double endDistance = _calculateDistance(_currentPosition!, lapTimerModel.endPosition!);
      if (endDistance <= 10.0) {
        _stopStopwatch();
        _recordLap();
      }
    }
  }

  double _calculateDistance(GpsData a, GpsData b) {
    const double earthRadius = 6371000; // meters
    double dLat = _degreesToRadians(b.latitude - a.latitude);
    double dLon = _degreesToRadians(b.longitude - a.longitude);

    double lat1 = _degreesToRadians(a.latitude);
    double lat2 = _degreesToRadians(b.latitude);

    double aHarv = sin(dLat / 2) * sin(dLat / 2) +
        sin(dLon / 2) * sin(dLon / 2) * cos(lat1) * cos(lat2);
    double cHarv = 2 * atan2(sqrt(aHarv), sqrt(1 - aHarv));
    return earthRadius * cHarv;
  }

  double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }

  void _startStopwatch() {
    setState(() {
      _stopwatch.start();
      _timer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
        setState(() {});
      });
      logger.i('Stopwatch started');
    });
  }

  void _stopStopwatch() {
    setState(() {
      _stopwatch.stop();
      _timer?.cancel();
      logger.i('Stopwatch stopped');
    });
  }

  void _resetStopwatch() {
    setState(() {
      _stopwatch.reset();
      Provider.of<LapModel>(context, listen: false).resetLapTimes();
      logger.i('Stopwatch reset');
    });
  }

  void _recordLap() {
    final lapTime = _stopwatch.elapsed;
    setState(() {
      Provider.of<LapModel>(context, listen: false).addLapTime(lapTime);
      _stopwatch.reset();
      final lapTimerModel = Provider.of<LapTimerModel>(context, listen: false);
      if (lapTimerModel.mode == 'Track') {
        _stopwatch.start();
      }
      logger.i('Lap recorded: $lapTime');
    });
  }

  void _markPosition() {
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('GPS data not available')),
      );
      return;
    }

    final lapTimerModel = Provider.of<LapTimerModel>(context, listen: false);
    final mode = lapTimerModel.mode;

    if (mode == 'Autocross') {
      if (lapTimerModel.startPosition == null) {
        lapTimerModel.setStartPosition(_currentPosition!);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Start position marked')),
        );
      } else if (lapTimerModel.endPosition == null) {
        lapTimerModel.setEndPosition(_currentPosition!);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('End position marked')),
        );
      } else {
        lapTimerModel.setStartPosition(_currentPosition!);
        lapTimerModel.setEndPosition(null);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Start position re-marked. Please mark end position.')),
        );
      }
    } else {
      lapTimerModel.setLapPoint(_currentPosition!);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lap point marked')),
      );
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    final milliseconds = twoDigits(duration.inMilliseconds.remainder(1000) ~/ 10);
    return '$minutes:$seconds.$milliseconds';
  }

  @override
  void dispose() {
    _gpsSubscription?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lapModel = Provider.of<LapModel>(context);
    final lapTimerModel = Provider.of<LapTimerModel>(context);
    final elapsedTime = _formatDuration(_stopwatch.elapsed);

    if (widget.isLandscape) {
      // Landscape Layout
      final bestLap = lapModel.bestLapTime != null ? _formatDuration(lapModel.bestLapTime!) : '--:--.--';
      final lastLap = lapModel.lapTimes.isNotEmpty ? _formatDuration(lapModel.lapTimes.last) : '--:--.--';
      final lapCount = lapModel.lapTimes.length;

      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Lap $lapCount',
                style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 20),
              Text(
                elapsedTime,
                style: const TextStyle(fontSize: 100.0, fontWeight: FontWeight.bold, color: Colors.redAccent),
              ),
              const SizedBox(height: 20),
              Text(
                'Best Lap: $bestLap',
                style: const TextStyle(fontSize: 30, color: Colors.white),
              ),
              Text(
                'Last Lap: $lastLap',
                style: const TextStyle(fontSize: 30, color: Colors.white),
              ),
            ],
          ),
        ),
      );
    } else {
      // Portrait Layout
      String positionStatus;
      if (lapTimerModel.mode == 'Autocross') {
        if (lapTimerModel.startPosition == null) {
          positionStatus = 'Start position not set';
        } else if (lapTimerModel.endPosition == null) {
          positionStatus = 'End position not set';
        } else {
          positionStatus = 'Start and End positions set';
        }
      } else {
        if (lapTimerModel.lapPoint == null) {
          positionStatus = 'Lap point not set';
        } else {
          positionStatus = 'Lap point set';
        }
      }

      return SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${lapTimerModel.mode} Mode',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              positionStatus,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            Text(
              elapsedTime,
              style: const TextStyle(fontSize: 48.0, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _markPosition,
              child: Text(lapTimerModel.mode == 'Autocross' ? 'Mark Position' : 'Mark Lap Point'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                final lapTimerModel = Provider.of<LapTimerModel>(context, listen: false);
                lapTimerModel.resetPositions();
              },
              child: const Text('Reset Positions'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _resetStopwatch,
              child: const Text('Reset Timer'),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 150,
              child: ListView.builder(
                itemCount: lapModel.lapTimes.length,
                itemBuilder: (context, index) {
                  final lapTime = _formatDuration(lapModel.lapTimes[index]);
                  return ListTile(
                    title: Text('Lap ${index + 1}'),
                    trailing: Text(lapTime),
                  );
                },
              ),
            ),
          ],
        ),
      );
    }
  }
}