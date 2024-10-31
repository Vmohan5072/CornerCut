import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/session_model.dart';
import 'session_detail_screen.dart';

class SessionsScreen extends StatelessWidget {
  const SessionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sessionModel = Provider.of<SessionModel>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Previous Sessions'),
      ),
      body: ListView.builder(
        itemCount: sessionModel.sessions.length,
        itemBuilder: (context, index) {
          final session = sessionModel.sessions[index];
          return ListTile(
            title: Text('Session ${index + 1} - ${session.date}'),
            subtitle: Text('Best Lap: ${session.bestLapTime != null ? session.bestLapTime.toString() : '--:--.--'}'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SessionDetailScreen(session: session),
                ),
              );
            },
          );
        },
      ),
    );
  }
}