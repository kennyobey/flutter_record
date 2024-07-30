import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const VoiceNoteWidget(),
    );
  }
}

class VoiceNoteWidget extends StatefulWidget {
  const VoiceNoteWidget({super.key});

  @override
  _VoiceNoteWidgetState createState() => _VoiceNoteWidgetState();
}

class _VoiceNoteWidgetState extends State<VoiceNoteWidget> {
  final Record _record = Record();
  final AudioPlayer _player = AudioPlayer();
  String? _filePath;
  bool _isRecording = false;
  bool _isPlaying = false;
  bool _isPaused = false;
  Duration _recordingDuration = Duration.zero;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  Timer? _recordingTimer;
  Timer? _playbackTimer;

  @override
  void initState() {
    super.initState();
    _requestPermissions();

    // Listen for position changes
    _player.onPositionChanged.listen((position) {
      setState(() {
        _currentPosition = position;
      });
    });

    // Listen for duration changes
    _player.onDurationChanged.listen((duration) {
      setState(() {
        _totalDuration = duration;
      });
    });

    // Listen for player state changes
    _player.onPlayerStateChanged.listen((state) {
      setState(() {
        _isPlaying = state == PlayerState.playing;
        _isPaused = state == PlayerState.paused;
      });
    });
  }

  Future<void> _requestPermissions() async {
    if (await Permission.microphone.request().isGranted &&
        await Permission.storage.request().isGranted) {
      // Permissions granted
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permissions not granted')),
      );
    }
  }

  Future<void> _startRecording() async {
    final directory = await getApplicationDocumentsDirectory();
    _filePath =
        '${directory.path}/voice_note_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _record.start(
      path: _filePath!,
      encoder: AudioEncoder.AAC,
    );

    setState(() {
      _isRecording = true;
      _isPaused = false;
      _recordingDuration = Duration.zero;
    });

    _startRecordingTimer();
  }

  Future<void> _stopRecording() async {
    await _record.stop();
    setState(() {
      _isRecording = false;
    });
    _stopRecordingTimer();
  }

  Future<void> _playRecording() async {
    if (_filePath != null && !_isPlaying) {
      await _player.play(DeviceFileSource(_filePath!));
      setState(() {
        _isPlaying = true;
        _isPaused = false;
      });

      _startPlaybackTimer();
    }
  }

  Future<void> _pausePlaying() async {
    await _player.pause();
    setState(() {
      _isPaused = true;
    });
    _stopPlaybackTimer();
  }

  Future<void> _resumePlaying() async {
    await _player.resume();
    setState(() {
      _isPaused = false;
    });
    _startPlaybackTimer();
  }

  Future<void> _stopPlaying() async {
    await _player.stop();
    setState(() {
      _isPlaying = false;
      _isPaused = false;
    });
    _stopPlaybackTimer();
  }

  void _startRecordingTimer() {
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isRecording && !_isPaused) {
        setState(() {
          _recordingDuration =
              Duration(seconds: _recordingDuration.inSeconds + 1);
        });
      }
    });
  }

  void _stopRecordingTimer() {
    _recordingTimer?.cancel();
  }

  void _startPlaybackTimer() {
    _playbackTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isPlaying && !_isPaused) {
        setState(() {
          //_currentPosition = _player.position;
        });
      }
    });
  }

  void _stopPlaybackTimer() {
    _playbackTimer?.cancel();
  }

  @override
  void dispose() {
    _stopPlaying();
    _stopRecordingTimer();
    _stopPlaybackTimer();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: Icon(
                _isRecording ? Icons.stop : Icons.mic,
                size: 50,
              ),
              onPressed: () {
                if (_isRecording) {
                  _stopRecording();
                } else {
                  _startRecording();
                }
              },
            ),
            if (_isRecording)
              Text(
                'Recording: ${_recordingDuration.inSeconds}s',
                style: const TextStyle(fontSize: 16),
              ),
            if (_filePath != null && !_isRecording)
              Column(
                children: [
                  IconButton(
                    icon: Icon(
                      _isPlaying
                          ? (_isPaused ? Icons.play_arrow : Icons.pause)
                          : Icons.play_arrow,
                      size: 50,
                    ),
                    onPressed: () {
                      if (_isPlaying) {
                        if (_isPaused) {
                          _resumePlaying();
                        } else {
                          _pausePlaying();
                        }
                      } else {
                        _playRecording();
                      }
                    },
                  ),
                  if (_isPlaying || _isPaused)
                    Column(
                      children: [
                        Text(
                          '${_currentPosition.inSeconds}s / ${_totalDuration.inSeconds}s',
                          style: const TextStyle(fontSize: 16),
                        ),
                        LinearProgressIndicator(
                          value: _totalDuration.inMilliseconds > 0
                              ? _currentPosition.inMilliseconds /
                                  _totalDuration.inMilliseconds
                              : 0,
                        ),
                      ],
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
