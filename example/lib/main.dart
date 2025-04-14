import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:offline_transcription/offline_transcription.dart';
import 'package:offline_transcription/src/enhanced_transcription_result.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:path/path.dart' as path;

// Simple Audio recorder class using native recording functionality
class AudioRecorder {
  String? _recordedFilePath;
  bool _isRecording = false;
  final StreamController<double>? _amplitudeStreamController;
  Timer? _amplitudeTimer;
  RecorderController? _recorderController;

  AudioRecorder({StreamController<double>? amplitudeStreamController}) : _amplitudeStreamController = amplitudeStreamController;

  bool get isRecording => _isRecording;
  String? get recordedFilePath => _recordedFilePath;

  // Initialize the recorder
  Future<void> initialize() async {
    // Request permissions
    final micStatus = await Permission.microphone.request();
    final storageStatus = await Permission.storage.request();

    if (micStatus != PermissionStatus.granted || storageStatus != PermissionStatus.granted) {
      throw Exception('Microphone and storage permissions are required');
    }

    // Create temporary file for recording
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    _recordedFilePath = path.join(tempDir.path, 'rap_recording_$timestamp.aac');

    // Initialize recorder controller
    _recorderController = RecorderController()
      ..androidEncoder = AndroidEncoder.aac
      ..androidOutputFormat = AndroidOutputFormat.mpeg4
      ..iosEncoder = IosEncoder.kAudioFormatMPEG4AAC
      ..sampleRate = 44100;
  }

  // Start recording
  Future<void> startRecording() async {
    if (_recorderController == null) {
      await initialize();
    }

    // Start recording
    await _recorderController!.record(path: _recordedFilePath);
    _isRecording = true;

    // Simulate amplitude data for visualization
    if (_amplitudeStreamController != null) {
      _amplitudeTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
        // Generate random amplitude between 0.1 and 0.8 for visualization
        final double amplitude = 0.1 + (0.7 * DateTime.now().millisecondsSinceEpoch % 100) / 100;
        _amplitudeStreamController!.add(amplitude);
      });
    }
  }

  // Stop recording
  Future<String?> stopRecording() async {
    if (_recorderController == null || !_isRecording) {
      return null;
    }

    _amplitudeTimer?.cancel();

    await _recorderController!.stop();
    _isRecording = false;

    return _recordedFilePath;
  }

  // Dispose resources
  Future<void> dispose() async {
    _amplitudeTimer?.cancel();
    _recorderController?.dispose();
  }
}

// Recorder Widget for the UI
class RecorderWidget extends StatefulWidget {
  final Function(String) onRecordingComplete;

  const RecorderWidget({Key? key, required this.onRecordingComplete}) : super(key: key);

  @override
  State<RecorderWidget> createState() => _RecorderWidgetState();
}

class _RecorderWidgetState extends State<RecorderWidget> {
  late AudioRecorder _audioRecorder;
  final StreamController<double> _amplitudeStreamController = StreamController<double>();
  List<double> _amplitudes = [];
  bool _isRecording = false;
  String? _recordedFilePath;

  @override
  void initState() {
    super.initState();
    _audioRecorder = AudioRecorder(amplitudeStreamController: _amplitudeStreamController);
    _amplitudeStreamController.stream.listen((amplitude) {
      setState(() {
        _amplitudes.add(amplitude);
        // Keep a reasonable number of amplitude samples
        if (_amplitudes.length > 100) {
          _amplitudes.removeAt(0);
        }
      });
    });
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    _amplitudeStreamController.close();
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      await _audioRecorder.startRecording();
      setState(() {
        _isRecording = true;
        _amplitudes = [];
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error starting recording: $e')),
      );
    }
  }

  Future<void> _stopRecording() async {
    try {
      final filePath = await _audioRecorder.stopRecording();
      setState(() {
        _isRecording = false;
        _recordedFilePath = filePath;
      });

      if (filePath != null) {
        widget.onRecordingComplete(filePath);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error stopping recording: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Rap Recording',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 16),

            // Visualization of recording
            Container(
              height: 100,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: _isRecording
                  ? CustomPaint(
                      size: Size.infinite,
                      painter: WaveformPainter(
                        amplitudes: _amplitudes,
                        color: Colors.blue,
                      ),
                    )
                  : const Center(
                      child: Text('Press the mic button to start recording your rap'),
                    ),
            ),

            const SizedBox(height: 16),

            // Recording controls
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FloatingActionButton(
                  onPressed: _isRecording ? _stopRecording : _startRecording,
                  backgroundColor: _isRecording ? Colors.red : Colors.blue,
                  child: Icon(
                    _isRecording ? Icons.stop : Icons.mic,
                    color: Colors.white,
                  ),
                ),
              ],
            ),

            if (_recordedFilePath != null) ...[
              const SizedBox(height: 16),
              Text(
                'Recording saved to: ${path.basename(_recordedFilePath!)}',
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
            ],

            const SizedBox(height: 8),
            const Text(
              'Record your rap to analyze rhymes, flow patterns, and verses. The AI will highlight rhyming words and detect your rap style.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

// Custom painter for live waveform visualization
class WaveformPainter extends CustomPainter {
  final List<double> amplitudes;
  final Color color;

  WaveformPainter({required this.amplitudes, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    if (amplitudes.isEmpty) return;

    final path = Path();
    final width = size.width;
    final height = size.height;
    final centerY = height / 2;

    final pointsPerSample = width / amplitudes.length;

    path.moveTo(0, centerY);

    for (int i = 0; i < amplitudes.length; i++) {
      final x = i * pointsPerSample;
      final amplitude = amplitudes[i].clamp(0.0, 1.0);
      final y = centerY - (amplitude * height / 2);
      path.lineTo(x, y);
    }

    for (int i = amplitudes.length - 1; i >= 0; i--) {
      final x = i * pointsPerSample;
      final amplitude = amplitudes[i].clamp(0.0, 1.0);
      final y = centerY + (amplitude * height / 2);
      path.lineTo(x, y);
    }

    path.close();

    final fillPaint = Paint()
      ..color = color.withOpacity(0.2)
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant WaveformPainter oldDelegate) {
    return oldDelegate.amplitudes != amplitudes;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _platformVersion = 'Unknown';
  String _permissionStatus = 'Unknown';
  String _selectedAudioPath = '';
  String _modelPath = '';
  bool _isTranscribing = false;
  bool _isDownloadingModel = false;
  bool _isInitialized = false;
  String _selectedLanguage = 'en_us';
  bool _forceTranscription = false;

  // Add a key for ScaffoldMessenger
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  EnhancedTranscriptionResult? _transcriptionResult;
  final _offlineTranscriptionPlugin = OfflineTranscription();
  PlayerController? _playerController;
  double _audioDuration = 0.0;

  @override
  void initState() {
    super.initState();
    _initPlugin();
  }

  Future<void> _initPlugin() async {
    try {
      await _offlineTranscriptionPlugin.initialize();
      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      print('Error initializing plugin: $e');
    }

    initPlatformState();
    checkPermission();
    _initModelPath();
  }

  // Initialize model path based on platform
  Future<void> _initModelPath() async {
    if (Platform.isAndroid) {
      final appDir = await getApplicationDocumentsDirectory();
      setState(() {
        _modelPath = '${appDir.path}/vosk_model';
      });
    }
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    String platformVersion;
    // Platform messages may fail, so we use a try/catch PlatformException.
    // We also handle the message potentially returning null.
    try {
      platformVersion = await _offlineTranscriptionPlugin.getPlatformVersion() ?? 'Unknown platform version';
    } on PlatformException {
      platformVersion = 'Failed to get platform version.';
    }

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;

    setState(() {
      _platformVersion = platformVersion;
    });
  }

  // Check speech recognition permission
  Future<void> checkPermission() async {
    try {
      final status = await _offlineTranscriptionPlugin.checkPermission();
      setState(() {
        _permissionStatus = status ?? 'Unknown';
      });
    } on PlatformException catch (e) {
      setState(() {
        _permissionStatus = 'Error: ${e.message}';
      });
    }
  }

  // Request speech recognition permission
  Future<void> requestPermission() async {
    try {
      final status = await _offlineTranscriptionPlugin.requestPermission();
      setState(() {
        _permissionStatus = status ?? 'Unknown';
      });
    } on PlatformException catch (e) {
      setState(() {
        _permissionStatus = 'Error: ${e.message}';
      });
    }
  }

  // Pick an audio file
  Future<void> pickAudioFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );

      if (result != null) {
        setState(() {
          _selectedAudioPath = result.files.single.path!;
        });

        // Initialize audio player
        await _initAudioPlayer();
      }
    } catch (e) {
      print('Error picking audio file: $e');
    }
  }

  // Initialize audio player
  Future<void> _initAudioPlayer() async {
    if (_selectedAudioPath.isEmpty) return;

    try {
      _playerController?.dispose();
      _playerController = PlayerController();
      await _playerController!.preparePlayer(
        path: _selectedAudioPath,
        noOfSamples: 100,
      );

      // Get audio duration
      final audioFile = File(_selectedAudioPath);
      final bytes = await audioFile.readAsBytes();
      _audioDuration = await _playerController!.getDuration() / 1000; // Convert to seconds
      setState(() {});
    } catch (e) {
      print('Error initializing audio player: $e');
    }
  }

  // Download model (Android only)
  Future<void> downloadModel() async {
    if (!Platform.isAndroid) {
      _showSnackBar('Model download is only available on Android');
      return;
    }

    setState(() {
      _isDownloadingModel = true;
    });

    try {
      // URL for the appropriate language model
      String modelUrl;
      switch (_selectedLanguage) {
        case 'en_us':
          modelUrl = 'https://alphacephei.com/vosk/models/vosk-model-small-en-us-0.15.zip';
          break;
        case 'en_uk':
          modelUrl = 'https://alphacephei.com/vosk/models/vosk-model-small-en-0.15.zip';
          break;
        case 'pt_PT':
          modelUrl = 'https://alphacephei.com/vosk/models/vosk-model-small-pt-0.3.zip';
          break;
        default:
          modelUrl = 'https://alphacephei.com/vosk/models/vosk-model-small-en-us-0.15.zip';
      }

      final success = await _offlineTranscriptionPlugin.downloadModel(
        modelUrl,
        _modelPath,
        language: _selectedLanguage,
      );

      if (success == true) {
        _showSnackBar('Model downloaded successfully');
      } else {
        _showSnackBar('Failed to download model');
      }
    } catch (e) {
      _showSnackBar('Error downloading model: $e');
    } finally {
      setState(() {
        _isDownloadingModel = false;
      });
    }
  }

  // Transcribe audio file with enhanced features
  Future<void> transcribeAudio() async {
    if (_selectedAudioPath.isEmpty) {
      _showSnackBar('Please select an audio file first');
      return;
    }

    if (Platform.isAndroid && _modelPath.isEmpty) {
      _showSnackBar('Please download a model first (Android only)');
      return;
    }

    setState(() {
      _isTranscribing = true;
      _transcriptionResult = null;
    });

    try {
      // Verify that the audio file exists and can be read
      final audioFile = File(_selectedAudioPath);
      if (!await audioFile.exists()) {
        _showSnackBar('Audio file does not exist: $_selectedAudioPath');
        return;
      }

      final fileSize = await audioFile.length();
      if (fileSize == 0) {
        _showSnackBar('Audio file is empty (0 bytes)');
        return;
      }

      _showSnackBar('Processing audio file: ${fileSize ~/ 1024} KB');

      // Set the language
      _offlineTranscriptionPlugin.currentLanguage = _selectedLanguage;

      // Log the parameters we're sending
      print('Transcribing audio file:');
      print('  Path: $_selectedAudioPath');
      print('  Model path: ${Platform.isAndroid ? _modelPath : "Using iOS built-in"}');
      print('  Language: $_selectedLanguage');
      print('  Force Transcription: $_forceTranscription');
      print('  Audio duration: $_audioDuration seconds');

      // Transcribe with metadata to get the raw result
      final result = await _offlineTranscriptionPlugin.transcribeAudioFileWithMetadata(_selectedAudioPath,
          modelPath: Platform.isAndroid ? _modelPath : null, language: _selectedLanguage, forceTranscription: _forceTranscription);

      // Print the raw result for debugging
      print('Raw transcription result: $result');

      if (result == null || result.isEmpty) {
        _showSnackBar('Transcription returned empty result');
        return;
      }

      // Try to decode the result directly to check if we get a valid JSON
      try {
        final Map<String, dynamic> jsonResult = json.decode(result);
        print('Decoded JSON result: $jsonResult');
        final String text = jsonResult['text'] ?? '';

        // Check if it's the music content detection message
        if (text.contains("appears to be music with vocals") && !_forceTranscription) {
          _showSnackBar('Audio detected as music. Turn on "Force Transcription" to attempt transcription anyway.');
        } else if (text.isEmpty) {
          _showSnackBar('Transcription produced no text. The audio may not contain recognizable speech.');
        }
      } catch (e) {
        print('Error decoding JSON result: $e');
      }

      // Continue with the enhanced processing
      final enhancedResult = await _offlineTranscriptionPlugin.transcribeAudioFileEnhanced(
        _selectedAudioPath,
        modelPath: Platform.isAndroid ? _modelPath : null,
        language: _selectedLanguage,
        detectRhymes: true,
        detectSlang: true,
        analyzeTiming: true,
        totalDuration: _audioDuration,
      );

      setState(() {
        _transcriptionResult = enhancedResult;
      });

      if (_transcriptionResult?.text?.isEmpty ?? true) {
        _showSnackBar('Transcription completed but no text was detected in the audio');
      } else {
        _showSnackBar('Transcription completed successfully');
      }
    } catch (e, stackTrace) {
      print('Error transcribing audio: $e');
      print('Stack trace: $stackTrace');
      _showSnackBar('Error transcribing audio: $e');
    } finally {
      setState(() {
        _isTranscribing = false;
      });
    }
  }

  // Helper method to show SnackBar
  void _showSnackBar(String message) {
    _scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // Get text spans for rich text display with highlighting
  List<TextSpan> _getHighlightedText() {
    if (_transcriptionResult == null) {
      return [const TextSpan(text: 'No transcription yet')];
    }

    final text = _transcriptionResult!.text;
    final annotations = _transcriptionResult!.annotations;

    // Sort annotations by start index
    annotations.sort((a, b) => a.start.compareTo(b.start));

    final List<TextSpan> spans = [];
    int currentIndex = 0;

    // Create a map of rhyme group colors
    final Map<int, Color> rhymeColors = {};
    final List<Color> colorPalette = [
      Colors.red.shade200,
      Colors.blue.shade200,
      Colors.green.shade200,
      Colors.orange.shade200,
      Colors.purple.shade200,
      Colors.teal.shade200,
      Colors.pink.shade200,
      Colors.amber.shade200,
    ];

    for (final annotation in annotations) {
      // Add text before the annotation
      if (annotation.start > currentIndex) {
        spans.add(TextSpan(
          text: text.substring(currentIndex, annotation.start),
          style: const TextStyle(color: Colors.black),
        ));
      }

      // Add the annotated text with appropriate styling
      final annotatedText = text.substring(annotation.start, annotation.end);

      switch (annotation.type) {
        case 'rhyme':
          final groupId = annotation.data['groupId'] as int;
          if (!rhymeColors.containsKey(groupId)) {
            rhymeColors[groupId] = colorPalette[groupId % colorPalette.length];
          }

          spans.add(TextSpan(
            text: annotatedText,
            style: TextStyle(
              color: Colors.black,
              backgroundColor: rhymeColors[groupId],
              fontWeight: FontWeight.bold,
            ),
          ));
          break;

        case 'slang':
          spans.add(TextSpan(
            text: annotatedText,
            style: const TextStyle(
              color: Colors.black,
              decoration: TextDecoration.underline,
              decorationColor: Colors.red,
              decorationStyle: TextDecorationStyle.wavy,
              fontStyle: FontStyle.italic,
            ),
          ));
          break;

        case 'phrase':
          spans.add(TextSpan(
            text: annotatedText,
            style: const TextStyle(color: Colors.black),
          ));
          break;

        case 'verse':
          spans.add(TextSpan(
            text: annotatedText,
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ));
          break;

        default:
          spans.add(TextSpan(
            text: annotatedText,
            style: const TextStyle(color: Colors.black),
          ));
      }

      currentIndex = annotation.end;
    }

    // Add any remaining text
    if (currentIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(currentIndex),
        style: const TextStyle(color: Colors.black),
      ));
    }

    return spans;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scaffoldMessengerKey: _scaffoldMessengerKey,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Enhanced Offline Transcription'),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
        body: _isInitialized
            ? _buildMainContent()
            : const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Initializing plugin...'),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildMainContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Running on: $_platformVersion'),
          const SizedBox(height: 16),

          // Language selection
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Language', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  DropdownButton<String>(
                    value: _selectedLanguage,
                    isExpanded: true,
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _selectedLanguage = newValue;
                        });
                      }
                    },
                    items: <String>['en_us', 'en_uk', 'pt_PT'].map<DropdownMenuItem<String>>((String value) {
                      String displayName;
                      switch (value) {
                        case 'en_us':
                          displayName = 'English (US)';
                          break;
                        case 'en_uk':
                          displayName = 'English (UK)';
                          break;
                        case 'pt_PT':
                          displayName = 'Portuguese (Portugal)';
                          break;
                        default:
                          displayName = value;
                      }
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(displayName),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Permission section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Speech Recognition Permission', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text('Status: $_permissionStatus'),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: requestPermission,
                    child: const Text('Request Permission'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Model section (Android only)
          if (Platform.isAndroid)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Speech Recognition Model (Android only)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    Text('Model path: ${_modelPath.isNotEmpty ? _modelPath : "Not set"}'),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _isDownloadingModel ? null : downloadModel,
                      child: _isDownloadingModel ? const CircularProgressIndicator() : const Text('Download Model'),
                    ),
                  ],
                ),
              ),
            ),
          if (Platform.isAndroid) const SizedBox(height: 16),

          // Audio file selection
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Audio File', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text('Selected file: ${_selectedAudioPath.isNotEmpty ? _selectedAudioPath : "None"}'),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: pickAudioFile,
                    child: const Text('Select Audio File'),
                  ),
                  if (_playerController != null && _selectedAudioPath.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: AudioFileWaveforms(
                        size: Size(MediaQuery.of(context).size.width - 64, 100),
                        playerController: _playerController!,
                        enableSeekGesture: true,
                        waveformType: WaveformType.fitWidth,
                        playerWaveStyle: const PlayerWaveStyle(
                          fixedWaveColor: Colors.grey,
                          liveWaveColor: Colors.blue,
                          spacing: 6,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Recorder Widget
          RecorderWidget(
            onRecordingComplete: (filePath) {
              setState(() {
                _selectedAudioPath = filePath;
              });
              _initAudioPlayer();
            },
          ),
          const SizedBox(height: 16),

          // Force transcription toggle
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Force Transcription on Music Files', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Switch(
                    value: _forceTranscription,
                    onChanged: (bool value) {
                      setState(() {
                        _forceTranscription = value;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Transcription section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Enhanced Transcription', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _isTranscribing ? null : transcribeAudio,
                    child: _isTranscribing ? const CircularProgressIndicator() : const Text('Transcribe Audio'),
                  ),
                  const SizedBox(height: 16),
                  const Text('Result with Highlighting:'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(4.0),
                    ),
                    child: RichText(
                      text: TextSpan(
                        children: _getHighlightedText(),
                      ),
                    ),
                  ),

                  // Legend
                  if (_transcriptionResult != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Legend:', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Container(
                                width: 16,
                                height: 16,
                                color: Colors.red.shade200,
                              ),
                              const Text('Rhyming words (same color = same rhyme group)'),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                'Slang',
                                style: TextStyle(
                                  decoration: TextDecoration.underline,
                                  decorationColor: Colors.red,
                                  decorationStyle: TextDecorationStyle.wavy,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                              Text('Slang words'),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text('Text', style: TextStyle(fontWeight: FontWeight.bold)),
                              Text('Verse boundaries'),
                            ],
                          ),
                        ],
                      ),
                    ),

                  // Metadata display
                  if (_transcriptionResult != null)
                    ExpansionTile(
                      title: const Text('Detailed Metadata'),
                      children: [
                        _buildMetadataSection(),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataSection() {
    if (_transcriptionResult == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Rhyme groups
        const Text('Rhyme Groups:', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        ...(_transcriptionResult!.annotations.where((a) => a.type == 'rhyme').map((a) => a.data['groupId'] as int).toSet().map((groupId) {
          final rhymingWords = _transcriptionResult!.words.where((w) => w.rhymeGroupId == groupId).map((w) => w.text).toList();

          return Padding(
            padding: const EdgeInsets.only(bottom: 4.0),
            child: Text('Group $groupId: ${rhymingWords.join(', ')}'),
          );
        })),

        const SizedBox(height: 8),

        // Slang words
        const Text('Slang Words:', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(_transcriptionResult!.words.where((w) => w.isSlang).map((w) => w.text).toList().join(', ')),

        const SizedBox(height: 8),

        // Segments
        const Text('Segments:', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        ...(_transcriptionResult!.segments.map((segment) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 4.0),
            child: Text(
              '${segment.type.toUpperCase()} (${segment.start.toStringAsFixed(2)}s - ${segment.end.toStringAsFixed(2)}s): "${segment.text}"',
              style: TextStyle(
                fontWeight: segment.type == 'verse' ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          );
        })),
      ],
    );
  }

  @override
  void dispose() {
    _playerController?.dispose();
    super.dispose();
  }
}
