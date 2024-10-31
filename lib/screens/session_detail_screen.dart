
import 'package:flutter/material.dart';
import '../models/session.dart';

class SessionDetailScreen extends StatelessWidget {
  final Session session;
  const SessionDetailScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Session Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.video_library),
            onPressed: () {
              // Implement GoPro footage linking
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Associate GoPro footage')),
              );
            },
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: session.lapTimes.length,
        itemBuilder: (context, index) {
          final lapTime = session.lapTimes[index];
          return ListTile(
            title: Text('Lap ${index + 1}'),
            trailing: Text(lapTime.toString()),
          );
        },
      ),
    );
  }
}