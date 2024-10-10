// home_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart' as app_logger;
import 'dart:async'; // Import for StreamSubscription

import '../services/gps_service.dart';
import '../services/permission_service.dart';
import '../widgets/lap_timer.dart';
import '../models/telemetry_model.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  final app_logger.Logger logger = app_logger.Logger();

  late GpsService _gpsService;
  late TelemetryModel _telemetryModel;
  StreamSubscription<GpsData>? _gpsSubscription;

  @override
  void initState() {
    super.initState();
    // Access GpsService and TelemetryModel from Provider after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _gpsService = Provider.of<GpsService>(context, listen: false);
      _telemetryModel = Provider.of<TelemetryModel>(context, listen: false);
      initGps();
    });
  }

  // Initialize GPS and request permissions
  void initGps() async {
    bool hasPermission = await PermissionService.requestPermissions();
    if (hasPermission) {
      await _gpsService.initialize();
      // Listen to the gpsDataStream
      _gpsSubscription = _gpsService.gpsDataStream.listen((GpsData gpsData) {
        logger.d('Received GPS Data: $gpsData');
        // Update TelemetryModel with GPS data
        _telemetryModel.updateTelemetry(
          latitude: gpsData.latitude,
          longitude: gpsData.longitude,
          altitude: gpsData.altitude,
        );
      });
    } else {
      // Log permission denial
      logger.w('Location permission denied');
      // Show a SnackBar to inform the user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission denied')),
        );
      }
    }
  }

  @override
  void dispose() {
    _gpsSubscription?.cancel();
    _gpsService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Access telemetry data from Provider
    final telemetry = Provider.of<TelemetryModel>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lap Timer App'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bluetooth),
            onPressed: () {
              Navigator.pushNamed(context, '/obd-connection');
            },
            tooltip: 'Connect OBD-II Device',
          ),
          IconButton(
            icon: const Icon(Icons.video_library),
            onPressed: () {
              Navigator.pushNamed(context, '/video-selection');
            },
            tooltip: 'Select GoPro Video',
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              // Display GPS Data using Consumer
              const Text(
                'GPS Data',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Consumer<TelemetryModel>(
                builder: (context, telemetry, child) {
                  if (telemetry.dataPoints.isNotEmpty) {
                    final latestData = telemetry.dataPoints.last;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Latitude: ${latestData.latitude.toStringAsFixed(6)}',
                          style: const TextStyle(fontSize: 18),
                        ),
                        Text(
                          'Longitude: ${latestData.longitude.toStringAsFixed(6)}',
                          style: const TextStyle(fontSize: 18),
                        ),
                        Text(
                          'Altitude: ${latestData.altitude.toStringAsFixed(2)} meters',
                          style: const TextStyle(fontSize: 18),
                        ),
                      ],
                    );
                  } else {
                    return const Text(
                      'Waiting for GPS data...',
                      style: TextStyle(fontSize: 18),
                    );
                  }
                },
              ),
              const SizedBox(height: 20),
              // Display Telemetry Data using Consumer
              const Text(
                'Telemetry Data',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Consumer<TelemetryModel>(
                builder: (context, telemetry, child) {
                  if (telemetry.dataPoints.isNotEmpty) {
                    final latestData = telemetry.dataPoints.last;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Speed: ${latestData.speed.toStringAsFixed(2)} mph',
                          style: const TextStyle(fontSize: 18),
                        ),
                        Text(
                          'RPM: ${latestData.rpm.toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 18),
                        ),
                        Text(
                          'Throttle: ${latestData.throttle.toStringAsFixed(1)}%',
                          style: const TextStyle(fontSize: 18),
                        ),
                        Text(
                          'Brake: ${latestData.brake.toStringAsFixed(1)}%',
                          style: const TextStyle(fontSize: 18),
                        ),
                      ],
                    );
                  } else {
                    return const Text(
                      'Waiting for telemetry data...',
                      style: TextStyle(fontSize: 18),
                    );
                  }
                },
              ),
              const SizedBox(height: 30),
              // Include the Lap Timer widget
              const LapTimer(),
            ],
          ),
        ),
      ),
    );
  }
}