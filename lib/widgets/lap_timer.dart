import 'package:flutter/material.dart';
import 'dart:async';

class LapTimer extends StatefulWidget {
  @override
  _LapTimerState createState() => _LapTimerState();
}

class _LapTimerState extends State<LapTimer> {
  Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;
  List<Duration> _laps = [];

  void _startStopwatch() {
    _stopwatch.start();
    _timer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      setState(() {});
    });
  }

  void _stopStopwatch() {
    _stopwatch.stop();
    _timer?.cancel();
  }

  void _resetStopwatch() {
    _stopwatch.reset();
    setState(() {
      _laps.clear();
    });
  }

  void _recordLap() {
    setState(() {
      _laps.add(_stopwatch.elapsed);
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes);
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    final milliseconds = (duration.inMilliseconds.remainder(1000) ~/ 10)
        .toString()
        .padLeft(2, '0');
    return '$minutes:$seconds.$milliseconds';
  }

  @override
  Widget build(BuildContext context) {
    final elapsedTime = _formatDuration(_stopwatch.elapsed);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          elapsedTime,
          style: const TextStyle(fontSize: 48.0, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 10,
          children: [
            ElevatedButton(
              onPressed: _stopwatch.isRunning ? _stopStopwatch : _startStopwatch,
              child: Text(_stopwatch.isRunning ? 'Stop' : 'Start'),
            ),
            ElevatedButton(
              onPressed: _stopwatch.isRunning ? _recordLap : null,
              child: const Text('Lap'),
            ),
            ElevatedButton(
              onPressed: _resetStopwatch,
              child: const Text('Reset'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Expanded(
          child: ListView.builder(
            itemCount: _laps.length,
            itemBuilder: (context, index) {
              final lapTime = _formatDuration(_laps[index]);
              return ListTile(
                title: Text('Lap ${index + 1}'),
                trailing: Text(lapTime),
              );
            },
          ),
        ),
      ],
    );
  }
}