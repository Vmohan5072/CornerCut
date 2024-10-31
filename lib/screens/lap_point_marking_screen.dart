import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../services/gps_service.dart';
import '../models/lap_timer_model.dart';
import 'home_screen.dart';

class LapPointMarkingScreen extends StatefulWidget {
  const LapPointMarkingScreen({super.key});

  @override
  LapPointMarkingScreenState createState() => LapPointMarkingScreenState();
}

class LapPointMarkingScreenState extends State<LapPointMarkingScreen> {
  GpsData? _currentPosition;

  StreamSubscription<GpsData>? _gpsSubscription;

  @override
  void initState() {
    super.initState();
    final gpsService = Provider.of<GpsService>(context, listen: false);
    _gpsSubscription = gpsService.gpsDataStream.listen((GpsData gpsData) {
      setState(() {
        _currentPosition = gpsData;
      });
    });
  }

  @override
  void dispose() {
    _gpsSubscription?.cancel();
    super.dispose();
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
      } 
      
      else if (lapTimerModel.endPosition == null) {
        lapTimerModel.setEndPosition(_currentPosition!);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('End position marked')),
        );
        _navigateToHomeScreen();
      }
    } 
    
    else {
      lapTimerModel.setLapPoint(_currentPosition!);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lap point marked')),
      );
      _navigateToHomeScreen();
    }
  }

  void _navigateToHomeScreen() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const HomeScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lapTimerModel = Provider.of<LapTimerModel>(context);
    final mode = lapTimerModel.mode;

    String instructionText;
    if (mode == 'Autocross') {
      if (lapTimerModel.startPosition == null) {
        instructionText = 'Please mark the Start Position';
      }
      
       else if (lapTimerModel.endPosition == null) {
        instructionText = 'Please mark the End Position';
      }
      
       else {
        instructionText = 'Positions marked';
      }
    } else {
      instructionText = 'Please mark the Lap Point';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('$mode - Mark Positions'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              instructionText,
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              child: const Text('Mark Position'),
              onPressed: _markPosition,
            ),
          ],
        ),
      ),
    );
  }
}