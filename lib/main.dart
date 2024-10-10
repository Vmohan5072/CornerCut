import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/telemetry_model.dart';
import 'models/lap_model.dart';
import 'screens/home_screen.dart';
import 'screens/obd_connection_screen.dart';
import 'screens/video_selection_screen.dart';
import 'services/gps_service.dart'; // Import GpsService
import 'services/bluetooth_service.dart'; // Import BluetoothService

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TelemetryModel()),
        ChangeNotifierProvider(create: (_) => LapModel()),
        Provider(create: (_) => GpsService()),
        Provider(create: (_) => BluetoothService()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lap Timer App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        textTheme: const TextTheme(
          headlineSmall: TextStyle(
            fontSize: 20.0,
            fontWeight: FontWeight.bold,
          ),
          bodyMedium: TextStyle(fontSize: 16.0),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const HomeScreen(),
        '/obd-connection': (context) => const ObdConnectionScreen(),
        '/video-selection': (context) => const VideoSelectionScreen(),
      },
    );
  }
}
