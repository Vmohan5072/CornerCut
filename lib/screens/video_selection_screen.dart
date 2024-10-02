import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'video_player_screen.dart';
import 'package:logger/logger.dart';

class VideoSelectionScreen extends StatefulWidget {
  const VideoSelectionScreen({super.key});

  @override
  VideoSelectionScreenState createState() => VideoSelectionScreenState();
}

class VideoSelectionScreenState extends State<VideoSelectionScreen> {
  String? _videoPath;
  final Logger logger = Logger();

  Future<void> _pickVideo() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.video);

    if (result != null && result.files.single.path != null) {
      setState(() {
        _videoPath = result.files.single.path!;
      });

      // Log video selection
      logger.d('Video selected: $_videoPath');

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VideoPlayerScreen(
            videoPath: _videoPath!,
          ),
        ),
      );
    } else {
      // User canceled the picker
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No video selected')),
      );
      logger.w('No video selected');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Select Video'),
        ),
        body: Center(
          child: ElevatedButton(
            onPressed: _pickVideo,
            child: const Text('Pick Video'),
          ),
        ));
  }
}