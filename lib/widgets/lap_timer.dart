import 'package:flutter/material.dart';
import 'dart:async';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import '../models/lap_model.dart';

class LapTimer extends StatefulWidget {
  const LapTimer({super.key});

  @override
  LapTimerState createState() => LapTimerState();
}

class LapTimerState extends State<LapTimer> {
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;
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
      Provider.of<LapModel>(context, listen: false).resetLapTimes();
      logger.i('Stopwatch reset');
    });
  }

  void _recordLap() {
    final lapTime = _stopwatch.elapsed;
    setState(() {
      Provider.of<LapModel>(context, listen: false).addLapTime(lapTime);
      _stopwatch.reset();
      _stopwatch.start();
      logger.i('Lap recorded: $lapTime');
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
    final lapModel = Provider.of<LapModel>(context);
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
    );
  }
}