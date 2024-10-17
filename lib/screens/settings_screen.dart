import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  SettingsScreenState createState() => SettingsScreenState();
}

class SettingsScreenState extends State<SettingsScreen> {
  String _unit = 'mph';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Units'),
            subtitle: const Text('Select units for speed'),
            trailing: DropdownButton<String>(
              value: _unit,
              items: const [
                DropdownMenuItem(
                  value: 'mph',
                  child: Text('mph'),
                ),
                DropdownMenuItem(
                  value: 'km/h',
                  child: Text('km/h'),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _unit = value!;
                  // Save to settings provider or local storage
                });
              },
            ),
          ),
          // Additional settings options
        ],
      ),
    );
  }
}