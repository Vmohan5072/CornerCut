import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/telemetry_model.dart';
import 'screens/home_screen.dart';
import 'screens/obd_connection_screen.dart';
import 'screens/video_selection_screen.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TelemetryModel()),
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