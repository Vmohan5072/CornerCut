import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import '../models/telemetry_model.dart';
import '../models/lap_model.dart';
import '../widgets/overlay_widgets.dart';
import 'dart:io';
import 'package:ffmpeg_kit_flutter_full_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/return_code.dart';
import 'package:intl/intl.dart';

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
  DateTime? _videoStartTime;
  double _timeOffset = 0.0; // Allows user to manually adjust footage and telemetry timing if desynced

  TelemetryData? _currentTelemetryData;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
    _extractVideoStartTime();
  }

  // Initialize the VideoPlayerController
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
        _controller.addListener(_updateTelemetryData);
      }).catchError((error) {
        _logger.e('Error initializing video: $error');
      });
  }

  // Extract the video's start time using FFmpeg
  void _extractVideoStartTime() async {
    String command =
        "-i \"${widget.videoPath}\" -f ffmetadata -"; // FFmpeg command to get metadata
    _logger.d('Executing FFmpeg command: $command');

    await FFmpegKit.executeAsync(command, (session) async {
      final returnCode = await session.getReturnCode();
      if (ReturnCode.isSuccess(returnCode)) {
        final output = await session.getOutput();
        _logger.d('FFmpeg output: $output');

        // Parse the output to find the creation_time
        RegExp regExp = RegExp(r'creation_time\s*:\s*(.*)');
        Match? match = regExp.firstMatch(output ?? '');

        if (match != null) {
          String creationTimeStr = match.group(1)!;
          _logger.d('Video creation time: $creationTimeStr');

          // Parse the creation time string into DateTime
          DateTime? creationTime = DateTime.tryParse(creationTimeStr);

          if (creationTime != null) {
            setState(() {
              _videoStartTime = creationTime.toUtc();
            });
            _logger.i('Video start time set: $_videoStartTime');
          } else {
            _logger.e('Failed to parse creation time.');
          }
        } else {
          _logger.e('creation_time not found in metadata.');
        }
      } else {
        _logger.e('FFmpeg command failed with return code: $returnCode');
      }
    });
  }

  // Update telemetry data based on video playback position
  void _updateTelemetryData() {
    if (_videoStartTime != null) {
      final videoPosition = _controller.value.position;
      final adjustedVideoTime = _videoStartTime!.add(
        Duration(
          milliseconds:
              (videoPosition.inMilliseconds + (_timeOffset * 1000).toInt()),
        ),
      );

      final telemetry = Provider.of<TelemetryModel>(context, listen: false);
      final dataPoint = telemetry.getTelemetryAt(adjustedVideoTime);

      setState(() {
        _currentTelemetryData = dataPoint;
      });
    }
  }

  // Toggle the visibility of the telemetry overlay
  void _toggleOverlay() {
    setState(() {
      _isOverlayVisible = !_isOverlayVisible;
    });
    _logger.d('Telemetry overlay visibility toggled: $_isOverlayVisible');
  }

  // Update the time offset based on user input
  void _updateTimeOffset(double value) {
    setState(() {
      _timeOffset = value;
    });
    _logger.d('Time offset updated to: $_timeOffset seconds');
  }

  @override
  void dispose() {
    _controller.removeListener(_updateTelemetryData);
    _controller.dispose();
    super.dispose();
    _logger.i('VideoPlayerController disposed.');
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) return '--:--.--';
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    final milliseconds =
        twoDigits(duration.inMilliseconds.remainder(1000) ~/ 10);
    return '$minutes:$seconds.$milliseconds';
  }

  @override
  Widget build(BuildContext context) {
    final telemetryData = _currentTelemetryData;
    final lapModel = Provider.of<LapModel>(context);

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
          // Telemetry Overlay
          if (_isOverlayVisible && telemetryData != null)
            Positioned(
              bottom: 80,
              left: 20,
              right: 20,
              child: Column(
                children: [
                  // Gauges Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      SizedBox(
                        width: 100,
                        height: 100,
                        child: SpeedometerGauge(speed: telemetryData.speed),
                      ),
                      SizedBox(
                        width: 100,
                        height: 100,
                        child: TachometerGauge(rpm: telemetryData.rpm),
                      ),
                      ThrottleBrakeIndicator(
                        throttle: telemetryData.throttle,
                        brake: telemetryData.brake,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Lap Times
                  Container(
                    padding: const EdgeInsets.all(10),
                    color: Colors.black54,
                    child: Column(
                      children: [
                        Text(
                          'Best Lap: ${_formatDuration(lapModel.bestLapTime)}',
                          style:
                              const TextStyle(color: Colors.white, fontSize: 16),
                        ),
                        Text(
                          'Current Lap: ${_formatDuration(lapModel.currentLapTime)}',
                          style:
                              const TextStyle(color: Colors.white, fontSize: 16),
                        ),
                        Text(
                          'Previous Lap: ${_formatDuration(lapModel.previousLapTime)}',
                          style:
                              const TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          // Time Offset Slider
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Column(
              children: [
                const Text(
                  'Time Offset Adjustment (seconds)',
                  style: TextStyle(color: Colors.white),
                ),
                Slider(
                  value: _timeOffset,
                  min: -5.0,
                  max: 5.0,
                  divisions: 100,
                  label: _timeOffset.toStringAsFixed(2),
                  onChanged: (double value) {
                    _updateTimeOffset(value);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            _controller.value.isPlaying
                ? _controller.pause()
                : _controller.play();
          });
          _logger.d(
              'Video play/pause toggled: ${_controller.value.isPlaying}');
        },
        tooltip: _controller.value.isPlaying ? 'Pause' : 'Play',
        child: Icon(
          _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
        ),
      ),
    );
  }
}