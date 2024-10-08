import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart' as app_logger;

import '../services/gps_service.dart';
import '../services/permission_service.dart';
import '../widgets/lap_timer.dart';
import '../models/telemetry_model.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  Position? _currentPosition;
  final app_logger.Logger logger = app_logger.Logger();

  @override
  void initState() {
    super.initState();
    initGps();
  }

  // Initialize GPS and request permissions
  void initGps() async {
    bool hasPermission = await PermissionService.requestPermissions(); // Updated method name
    if (hasPermission) {
      GpsService.getPositionStream().listen((Position position) {
        setState(() {
          _currentPosition = position;
          logger.d('Current position updated: $position');
        });
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
  Widget build(BuildContext context) {
    // Access telemetry data from Provider
    final telemetry = Provider.of<TelemetryModel>(context);

    final position = _currentPosition;

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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (position != null)
                Column(
                  children: [
                    Text(
                      'Latitude: ${position.latitude.toStringAsFixed(6)}',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    Text(
                      'Longitude: ${position.longitude.toStringAsFixed(6)}',
                      style: const TextStyle(fontSize: 18),
                    ),
                    Text(
                      // Convert m/s to mph
                      'Speed: ${(position.speed * 2.23694).toStringAsFixed(2)} mph',
                      style: const TextStyle(fontSize: 18),
                    ),
                  ],
                )
              else
                const Text(
                  'Waiting for position...',
                  style: TextStyle(fontSize: 18),
                ),
              const SizedBox(height: 10),
              // Display Telemetry Data
              Text(
                'Telemetry Data',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Text(
                'Speed: ${telemetry.dataPoints.isNotEmpty ? telemetry.dataPoints.last.speed.toStringAsFixed(2) : '0.00'} mph',
                style: const TextStyle(fontSize: 18),
              ),
              Text(
                'RPM: ${telemetry.dataPoints.isNotEmpty ? telemetry.dataPoints.last.rpm.toStringAsFixed(0) : '0'}',
                style: const TextStyle(fontSize: 18),
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