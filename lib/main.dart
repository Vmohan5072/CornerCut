import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/telemetry_model.dart';
import 'models/lap_model.dart';
import 'screens/home_screen.dart';
import 'screens/obd_connection_screen.dart';
import 'screens/video_selection_screen.dart';
import 'screens/settings_screen.dart';
import 'services/gps_service.dart';
import 'services/bluetooth_service.dart';
import 'services/data_storage_service.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TelemetryModel()),
        ChangeNotifierProvider(create: (_) => LapModel()),
        Provider(create: (_) => GpsService()),
        Provider(create: (_) => BluetoothService()),
        Provider(create: (_) => DataStorageService()),
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
      title: 'CornerCut',
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.redAccent,
        colorScheme: ColorScheme.dark(
          secondary: Colors.white, // Replaced accentColor with colorScheme.secondary
        ),
        fontFamily: 'Roboto',
        textTheme: const TextTheme(
          headlineSmall: TextStyle(
            fontSize: 20.0,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          bodyMedium: TextStyle(
            fontSize: 16.0,
            color: Colors.white70,
          ),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const HomeScreen(),
        '/obd-connection': (context) => const ObdConnectionScreen(),
        '/video-selection': (context) => const VideoSelectionScreen(),
        '/settings': (context) => const SettingsScreen(),
      },
    );
  }
}