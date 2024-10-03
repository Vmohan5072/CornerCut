import 'package:flutter/material.dart';
import 'dart:async';
import 'package:logger/logger.dart';

class LapTimer extends StatefulWidget {
  const LapTimer({super.key});

  @override
  LapTimerState createState() => LapTimerState();
}

class LapTimerState extends State<LapTimer> {
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;
  final List<Duration> _laps = [];
  final Logger logger = Logger();

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
      _laps.clear();
      logger.i('Stopwatch reset');
    });
  }

  void _recordLap() {
    setState(() {
      _laps.add(_stopwatch.elapsed);
      logger.i('Lap recorded: ${_stopwatch.elapsed}');
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    final milliseconds = twoDigits(duration.inMilliseconds.remainder(1000) ~/ 10);
    return '$minutes:$seconds.$milliseconds';
  }

  @override
  Widget build(BuildContext context) {
    final elapsedTime = _formatDuration(_stopwatch.elapsed);

    return Column(
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
        SizedBox(
          height: 150,
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