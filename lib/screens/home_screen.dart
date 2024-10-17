import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart' as app_logger;
import 'dart:async';
import '../services/gps_service.dart';
import '../services/permission_service.dart';
import '../widgets/lap_timer.dart';
import '../models/telemetry_model.dart';
import '../widgets/telemetry_dashboard.dart';
import '../screens/settings_screen.dart';
import '../widgets/lap_map.dart';

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

  int _currentIndex = 0;
  final List<Widget> _pages = [
    const DashboardScreen(),
    const LapTimerScreen(),
    const TelemetryScreen(),
    const SettingsScreen(),
  ];

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
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: Theme.of(context).colorScheme.secondary,
        unselectedItemColor: Colors.white70,
        backgroundColor: Colors.black,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.timer),
            label: 'Lap Timer',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.speed),
            label: 'Telemetry',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CornerCut Dashboard'),
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // GPS Data Card
            Card(
              child: ListTile(
                leading: const Icon(Icons.gps_fixed, color: Colors.redAccent),
                title: const Text('GPS Data'),
                subtitle: Consumer<TelemetryModel>(
                  builder: (context, telemetry, child) {
                    if (telemetry.latestData != null) {
                      final latestData = telemetry.latestData!;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Latitude: ${latestData.latitude.toStringAsFixed(6)}'),
                          Text('Longitude: ${latestData.longitude.toStringAsFixed(6)}'),
                          Text('Altitude: ${latestData.altitude.toStringAsFixed(2)} m'),
                        ],
                      );
                    } else {
                      return const Text('Waiting for GPS data...');
                    }
                  },
                ),
              ),
            ),
            // Telemetry Data Card
            Card(
              child: ListTile(
                leading: const Icon(Icons.speed, color: Colors.redAccent),
                title: const Text('Telemetry Data'),
                subtitle: Consumer<TelemetryModel>(
                  builder: (context, telemetry, child) {
                    if (telemetry.latestData != null) {
                      final latestData = telemetry.latestData!;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Speed: ${latestData.speed.toStringAsFixed(2)} mph'),
                          Text('RPM: ${latestData.rpm.toStringAsFixed(0)}'),
                          Text('Throttle: ${latestData.throttle.toStringAsFixed(1)}%'),
                          Text('Brake: ${latestData.brake.toStringAsFixed(1)}%'),
                        ],
                      );
                    } else {
                      return const Text('Waiting for telemetry data...');
                    }
                  },
                ),
              ),
            ),
            // Lap Timer
            const LapTimer(),
          ],
        ),
      ),
    );
  }
}

class LapTimerScreen extends StatelessWidget {
  const LapTimerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lap Timer'),
      ),
      body: const Center(
        child: LapTimer(),
      ),
    );
  }
}

class TelemetryScreen extends StatelessWidget {
  const TelemetryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Telemetry Dashboard'),
      ),
      body: const TelemetryDashboard(),
    );
  }
}