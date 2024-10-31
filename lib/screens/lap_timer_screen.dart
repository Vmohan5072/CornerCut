import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/lap_timer_model.dart';
import '../widgets/lap_timer.dart';

class LapTimerScreen extends StatefulWidget {
  const LapTimerScreen({super.key});

  @override
  _LapTimerScreenState createState() => _LapTimerScreenState();
}

class _LapTimerScreenState extends State<LapTimerScreen> {
  bool isLandscape = false;

  void _toggleOrientation() {
    setState(() {
      isLandscape = !isLandscape;
    });
  }

  @override
  Widget build(BuildContext context) {
    final lapTimerModel = Provider.of<LapTimerModel>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('${lapTimerModel.mode} Mode - Lap Timer'),
        actions: [
          IconButton(
            icon: const Icon(Icons.screen_rotation),
            onPressed: _toggleOrientation,
          ),
        ],
      ),
      body: isLandscape
          ? RotatedBox(
              quarterTurns: 1,
              child: LapTimer(isLandscape: isLandscape),
            )
          : LapTimer(isLandscape: isLandscape),
    );
  }
}