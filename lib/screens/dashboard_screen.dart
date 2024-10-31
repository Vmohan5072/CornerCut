import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/telemetry_model.dart';
import '../models/lap_timer_model.dart';
import 'lap_timer_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final lapTimerModel = Provider.of<LapTimerModel>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('CornerCut Dashboard'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // GPS Connection Status Card
            GestureDetector(
              onTap: () {
                // Navigate to GPS connection screen
                // For this example, we'll show a snackbar
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Navigate to GPS connection screen')),
                );
              },
              child: Card(
                child: ListTile(
                  leading: const Icon(Icons.gps_fixed, color: Colors.redAccent),
                  title: const Text('GPS Connection'),
                  subtitle: Consumer<TelemetryModel>(
                    builder: (context, telemetry, child) {
                      if (telemetry.latestData != null) {
                        return const Text('Connected');
                      } else {
                        return const Text('Waiting for GPS data...');
                      }
                    },
                  ),
                ),
              ),
            ),
            // Telemetry Connection Status Card
            GestureDetector(
              onTap: () {
                // Navigate to Telemetry connection screen
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Navigate to Telemetry connection screen')),
                );
              },
              child: Card(
                child: ListTile(
                  leading: const Icon(Icons.bluetooth, color: Colors.redAccent),
                  title: const Text('Telemetry Connection'),
                  subtitle: Consumer<TelemetryModel>(
                    builder: (context, telemetry, child) {
                      if (telemetry.latestData != null) {
                        return const Text('Connected');
                      } else {
                        return const Text('Waiting for Telemetry data...');
                      }
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Mode Selection
            Card(
              child: ListTile(
                title: const Text('Select Mode'),
                subtitle: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        lapTimerModel.setMode('Track');
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LapTimerScreen(),
                          ),
                        );
                      },
                      child: const Text('Track Mode'),
                    ),
                    const SizedBox(width: 20),
                    ElevatedButton(
                      onPressed: () {
                        lapTimerModel.setMode('Autocross');
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LapTimerScreen(),
                          ),
                        );
                      },
                      child: const Text('Autocross Mode'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
