import 'package:flutter/material.dart';

class OverlaySettings extends StatefulWidget {
  final Map<String, bool> initialSettings;
  final Function(Map<String, bool>) onSettingsChanged;

  const OverlaySettings({
    super.key,
    required this.initialSettings,
    required this.onSettingsChanged,
  });

  @override
  OverlaySettingsState createState() => OverlaySettingsState();
}

class OverlaySettingsState extends State<OverlaySettings> {
  late Map<String, bool> _settings;

  @override
  void initState() {
    super.initState();
    _settings = Map<String, bool>.from(widget.initialSettings);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: _settings.keys.map((key) {
        return CheckboxListTile(
          title: Text(key),
          value: _settings[key],
          onChanged: (value) {
            setState(() {
              _settings[key] = value!;
              widget.onSettingsChanged(_settings);
            });
          },
        );
      }).toList(),
    );
  }
}
