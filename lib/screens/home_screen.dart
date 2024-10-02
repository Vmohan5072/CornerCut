import 'package:flutter/material.dart';
import '../services/gps_service.dart';
import '../services/permission_service.dart';
import 'package:geolocator/geolocator.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    initGps();
  }

  void initGps() async {
    bool hasPermission = await PermissionService.requestLocationPermission();
    if (hasPermission) {
      GpsService.getPositionStream().listen((Position position) {
        setState(() {
          _currentPosition = position;
        });
      });
    } else {
      // Handle permission denied
      print('Location permission denied');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lap Timer App'),
      ),
      body: Center(
        child: _currentPosition != null
            ? Text(
                'Lat: ${_currentPosition!.latitude}, Lon: ${_currentPosition!.longitude}, Speed: ${_currentPosition!.speed} m/s')
            : const Text('Waiting for position...'),
      ),
    );
  }
}