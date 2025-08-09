import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: BottleScanner(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class BottleScanner extends StatefulWidget {
  @override
  _BottleScannerState createState() => _BottleScannerState();
}

class _BottleScannerState extends State<BottleScanner> {
  late CameraController _controller;
  bool _isInitialized = false;
  File? _capturedImage;
  double _lineY = 0;
  bool _showLoading = false;
  bool _showResult = false;
  double _lightYears = 0;
  double _ml = 0;
  String _loadingText = "Analysing image...";
  late VideoPlayerController _videoController;
  late GlobalKey _buttonKey;
  double _buttonWidth = 120;
  double _percentageOfLightSpeed = 0;

  int selectedCapacity = 1000;


  final List<String> loadingSteps = [
    "Analysing image...",
    "Counting atoms...",
    "Running simulation...",
    "Verifying quantum states...",
    "Finalizing calculation..."
  ];

  final double minY = 150; 
  final double maxY = 524; 

  @override
  void initState() {
    super.initState();
    _controller = CameraController(cameras[0], ResolutionPreset.medium);
    _controller.initialize().then((_) async {
      await _controller.setFlashMode(FlashMode.off);
      if (!mounted) return;
      setState(() => _isInitialized = true);
    });
    _videoController = VideoPlayerController.asset('assets/loading_screen.mp4')
      ..setLooping(true)
      ..initialize().then((_) => setState(() {}));
    _buttonKey = GlobalKey();
  }

  @override
  void dispose() {
    _controller.dispose();
    _videoController.dispose();
    super.dispose();
  }

  void _captureImage() async {
    final file = await _controller.takePicture();
    setState(() {
      _capturedImage = File(file.path);
    });
  }

  void _startAnalysis() {
  setState(() {
    _showLoading = true;
    _showResult = false;
  });

  int index = 0;
  _videoController.play();

  Timer.periodic(const Duration(seconds: 1), (timer) {
    if (index < loadingSteps.length) {
      setState(() => _loadingText = loadingSteps[index]);
      index++;
    } else {
      timer.cancel();
      double percentage = (maxY - _lineY) / (maxY - minY); 
      _ml = percentage * selectedCapacity;
      _lightYears = _ml / 1027;

      if (_lightYears > 1.0) {
        
        _percentageOfLightSpeed = sqrt(1 - pow(1 / _lightYears, 2)) * 100;
      }

      setState(() {
        _showLoading = false;
        _showResult = true;
      });
    }
  });
}

  Widget _buildResultWidget() {
    String displayText;
    if (_lightYears > 1.0) {
      displayText = "If the atoms in this amount of water were placed end-to-end, their length would appear to be exactly 1 light-year (considering you're travelling at ${_percentageOfLightSpeed.toStringAsFixed(2)}% of the speed of light.)";
    } else {
      displayText = "If the atoms in this water were arranged end to end, the total distance would be:\n\n${_lightYears.toStringAsFixed(2)} light years\n";
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Text(
          displayText,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 22),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    double defaultLineY = (522 + 134) / 2; // half
    _lineY = _lineY == 0 ? defaultLineY : _lineY;

    return Scaffold(
      body: _capturedImage == null
          ? Stack(
              children: [
                CameraPreview(_controller),
                Positioned.fill(
                  child: IgnorePointer(
                    child: Image.asset(
                      'assets/bottle_outline.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 140,
                  left: screenWidth * 0.5 - 75 - 100, 
                  child: DropdownButton<int>(
                    value: selectedCapacity,
                    items: const [750, 1000].map((value) => DropdownMenuItem(
                      value: value,
                      child: Text("$value ml"),
                    )).toList(),
                    onChanged: (value) => setState(() => selectedCapacity = value!),
                  ),
                ),

                Positioned(
                  bottom: 40,
                  left: screenWidth * 0.5 - _buttonWidth / 2,
                  child: ElevatedButton(
                    key: _buttonKey,
                    onPressed: () {
                      final RenderBox box = _buttonKey.currentContext?.findRenderObject() as RenderBox;
                      if (box.hasSize) {
                        setState(() {
                          _buttonWidth = box.size.width;
                        });
                      }
                      _captureImage();
                    },
                    child: const Text("Capture"),
                  ),
                ),
              ],
            )
          : _showLoading
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    if (_videoController.value.isInitialized)
                      Center(
                        child: SizedBox(
                          width: _buttonWidth,
                          height: _buttonWidth,
                          child: VideoPlayer(_videoController),
                        ),
                      ),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 220), 
                        child: Text(_loadingText,
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color.fromARGB(255, 0, 0, 0))),
                      ),
                    )
                  ],
                )
              : _showResult
                  ? _buildResultWidget()
                  : Stack(
                      children: [
                        Image.file(_capturedImage!, fit: BoxFit.cover, width: double.infinity),
                        Positioned.fill(
                          child: Image.asset('assets/bottle_outline.png', fit: BoxFit.cover),
                        ),
                        Positioned(
                          top: _lineY,
                          left: 0,
                          right: 0,
                          child: GestureDetector(
                            onVerticalDragUpdate: (details) {
                              setState(() {
                                _lineY += details.delta.dy;
                                print(" Line Y position: $_lineY");

                              });
                            },
                            child: Container(height: 4, color: Colors.blue),
                          ),
                        ),
                        Positioned(
                          bottom: 40,
                          left: screenWidth * 0.5 - _buttonWidth / 2,
                          child: ElevatedButton(
                            onPressed: _startAnalysis,
                            child: const Text("Begin Analysis"),
                          ),
                        ),
                      ],
                    ),
    );
  }
}