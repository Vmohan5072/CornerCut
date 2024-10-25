import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/lap_timer_model.dart';
import 'lap_point_marking_screen.dart';

class ModeSelectionScreen extends StatelessWidget {
  const ModeSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final lapTimerModel = Provider.of<LapTimerModel>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Mode'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            ElevatedButton(
              child: const Text('Track Mode'),
              onPressed: () {
                lapTimerModel.setMode('Track');
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LapPointMarkingScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              child: const Text('Autocross Mode'),
              onPressed: () {
                lapTimerModel.setMode('Autocross');
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LapPointMarkingScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
