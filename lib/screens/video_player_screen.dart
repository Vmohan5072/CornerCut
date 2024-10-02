// lib/screens/video_player_screen.dart

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import '../models/telemetry_model.dart';
import 'dart:io';

class VideoPlayerScreen extends StatefulWidget {
  final String videoPath;

  const VideoPlayerScreen({
    super.key,
    required this.videoPath,
  });

  @override
  VideoPlayerScreenState createState() => VideoPlayerScreenState();
}

class VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _controller;
  final Logger _logger = Logger();
  bool _isOverlayVisible = true;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  void _initializeVideo() {
    _controller = VideoPlayerController.file(
      File(widget.videoPath),
    )
      ..initialize().then((_) {
        setState(() {
          _controller.play();
          _controller.setLooping(false);
        });
        _logger.i('Video initialized and playing.');
      }).catchError((error) {
        _logger.e('Error initializing video: $error');
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
    _logger.i('VideoPlayerController disposed.');
  }

  void _toggleOverlay() {
    setState(() {
      _isOverlayVisible = !_isOverlayVisible;
    });
    _logger.d('Telemetry overlay visibility toggled: $_isOverlayVisible');
  }

  @override
  Widget build(BuildContext context) {
    // Access telemetry data from Provider
    final telemetry = Provider.of<TelemetryModel>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Playback with Telemetry'),
        actions: [
          IconButton(
            icon: Icon(
              _isOverlayVisible ? Icons.visibility_off : Icons.visibility,
            ),
            onPressed: _toggleOverlay,
            tooltip: _isOverlayVisible ? 'Hide Telemetry' : 'Show Telemetry',
          ),
        ],
      ),
      body: Stack(
        children: [
          Center(
            child: _controller.value.isInitialized
                ? AspectRatio(
                    aspectRatio: _controller.value.aspectRatio,
                    child: VideoPlayer(_controller),
                  )
                : const CircularProgressIndicator(),
          ),
          if (_isOverlayVisible)
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(10),
                color: Colors.black54,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Speed: ${telemetry.speed.toStringAsFixed(2)} mph',
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    Text(
                      'RPM: ${telemetry.rpm.toStringAsFixed(0)}',
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            _controller.value.isPlaying ? _controller.pause() : _controller.play();
          });
          _logger.d('Video play/pause toggled: ${_controller.value.isPlaying}');
        },
        child: Icon(
          _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
        ),
        tooltip: _controller.value.isPlaying ? 'Pause' : 'Play',
      ),
    );
  }
}