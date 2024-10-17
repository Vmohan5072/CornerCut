import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/telemetry_model.dart';
import 'overlay_widgets.dart';

class TelemetryDashboard extends StatelessWidget {
  const TelemetryDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final telemetry = Provider.of<TelemetryModel>(context);

    return telemetry.dataPoints.isNotEmpty
        ? SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Speedometer
                SizedBox(
                  width: 200,
                  height: 200,
                  child: SpeedometerGauge(speed: telemetry.currentSpeed),
                ),
                const SizedBox(height: 20),
                // Tachometer
                SizedBox(
                  width: 200,
                  height: 200,
                  child: TachometerGauge(rpm: telemetry.currentRpm),
                ),
                const SizedBox(height: 20),
                // Throttle and Brake Indicators
                ThrottleBrakeIndicator(
                  throttle: telemetry.currentThrottle,
                  brake: telemetry.currentBrake,
                ),
              ],
            ),
          )
        : const Center(child: CircularProgressIndicator());
  }
}