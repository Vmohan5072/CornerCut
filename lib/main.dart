import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/telemetry_model.dart';
import 'models/lap_model.dart';
import 'models/lap_timer_model.dart';
import 'screens/home_screen.dart';
import 'screens/video_selection_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/mode_selection_screen.dart';
import 'services/gps_service.dart';
import 'services/bluetooth_service.dart';
import 'services/data_storage_service.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TelemetryModel()),
        ChangeNotifierProvider(create: (_) => LapModel()),
        ChangeNotifierProvider(create: (_) => LapTimerModel()),
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
        colorScheme: const ColorScheme.dark(
          secondary: Colors.white,
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
      initialRoute: '/mode-selection',
      routes: {
        '/': (context) => const HomeScreen(),
        '/mode-selection': (context) => const ModeSelectionScreen(),
        '/video-selection': (context) => const VideoSelectionScreen(),
        '/settings': (context) => const SettingsScreen(),
      },
    );
  }
}