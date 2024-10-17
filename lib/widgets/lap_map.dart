import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../models/telemetry_model.dart';

class LapMap extends StatefulWidget {
  const LapMap({super.key});

  @override
  LapMapState createState() => LapMapState();
}

class LapMapState extends State<LapMap> {
  late GoogleMapController _mapController;
  final Set<Polyline> _polylines = {};
  final List<LatLng> _pathPoints = [];

  @override
  void initState() {
    super.initState();
    // Listen to telemetry data updates
    final telemetry = Provider.of<TelemetryModel>(context, listen: false);
    telemetry.addListener(_updatePath);
  }

  void _updatePath() {
    final telemetry = Provider.of<TelemetryModel>(context, listen: false);
    if (telemetry.latestData != null) {
      setState(() {
        _pathPoints.add(
          LatLng(telemetry.latestData!.latitude, telemetry.latestData!.longitude),
        );
        _polylines.add(
          Polyline(
            polylineId: const PolylineId('lapPath'),
            points: _pathPoints,
            color: Colors.red,
            width: 5,
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      initialCameraPosition: _pathPoints.isNotEmpty
          ? CameraPosition(
              target: _pathPoints.last,
              zoom: 16,
            )
          : const CameraPosition(
              target: LatLng(0, 0),
              zoom: 1,
            ),
      polylines: _polylines,
      onMapCreated: (controller) {
        _mapController = controller;
      },
    );
  }

  @override
  void dispose() {
    final telemetry = Provider.of<TelemetryModel>(context, listen: false);
    telemetry.removeListener(_updatePath);
    super.dispose();
  }
}