# Offline Transcription Plugin

A Flutter plugin for offline audio transcription on Android and iOS with enhanced features for rhyme detection, timing analysis, and slang detection.

Join my discord channel: https://discord.gg/8pem5GAe


## Features

[x] **Offline Audio Transcription**: Transcribe audio files locally on the device without sending data to the cloud
[] **Multi-language Support**: Support for English (US), English (UK), and Portuguese (Portugal)
[] **Rhyme Detection**: Identify and group rhyming words in transcriptions
[] **Timing Analysis**: Detect phrases and verses based on pauses in speech
[] **Slang Detection**: Identify slang words in transcriptions
[] **Rich Metadata**: Get detailed information about words, segments, and annotations
[] **Highlighting Support**: Use the metadata to highlight rhymes, slang, and segments in your UI

## Getting Started

### Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  offline_transcription: ^1.0.0
```

### Platform-specific Setup

#### Android

1. Add the following permissions to your `AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"/>
```

2. Set the minimum SDK version to 21 in your `android/app/build.gradle`:

```gradle
minSdkVersion 21
```

#### iOS

1. Add the following to your `Info.plist`:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>This app needs access to the microphone for speech recognition.</string>
<key>NSSpeechRecognitionUsageDescription</key>
<string>This app uses speech recognition to transcribe audio files.</string>
```

2. Set the minimum iOS version to 13.0 in your `ios/Podfile`:

```ruby
platform :ios, '13.0'
```

## Usage

### Basic Transcription

```dart
import 'package:offline_transcription/offline_transcription.dart';

// Create an instance of the plugin
final offlineTranscription = OfflineTranscription();

// Initialize the plugin
await offlineTranscription.initialize();

// Check and request permissions
final permissionStatus = await offlineTranscription.checkPermission();
if (permissionStatus != 'authorized') {
  await offlineTranscription.requestPermission();
}

// For Android, download a model (not needed for iOS)
if (Platform.isAndroid) {
  final modelPath = '/path/to/model/directory';
  await offlineTranscription.downloadModel(
    'https://alphacephei.com/vosk/models/vosk-model-small-en-us-0.15.zip',
    modelPath,
  );
}

// Transcribe an audio file
final transcription = await offlineTranscription.transcribeAudioFile(
  '/path/to/audio/file.mp3',
  modelPath: Platform.isAndroid ? '/path/to/model/directory' : null,
);

print('Transcription: $transcription');
```

### Enhanced Transcription with Metadata

```dart
import 'package:offline_transcription/offline_transcription.dart';
import 'package:offline_transcription/src/enhanced_transcription_result.dart';

// Create an instance of the plugin
final offlineTranscription = OfflineTranscription();

// Initialize the plugin
await offlineTranscription.initialize();

// Set the language (default is 'en_us')
offlineTranscription.currentLanguage = 'en_us'; // 'en_us', 'en_uk', or 'pt_PT'

// Transcribe with enhanced features
final result = await offlineTranscription.transcribeAudioFileEnhanced(
  '/path/to/audio/file.mp3',
  modelPath: Platform.isAndroid ? '/path/to/model/directory' : null,
  detectRhymes: true,
  detectSlang: true,
  analyzeTiming: true,
  totalDuration: 120.0, // Total duration in seconds (required for iOS timing analysis)
);

// Access the full transcription text
print('Transcription: ${result.text}');

// Access annotations (rhymes, slang, segments)
for (final annotation in result.annotations) {
  final annotatedText = result.text.substring(annotation.start, annotation.end);
  print('${annotation.type}: $annotatedText');
  
  if (annotation.type == 'rhyme') {
    print('Rhyme group ID: ${annotation.data['groupId']}');
  }
}

// Access word-level information
for (final word in result.words) {
  print('Word: ${word.text}, Start: ${word.start}s, End: ${word.end}s');
  
  if (word.rhymeGroupId != null) {
    print('Rhyme group: ${word.rhymeGroupId}');
  }
  
  if (word.isSlang) {
    print('This is slang');
  }
}

// Access segment information (phrases and verses)
for (final segment in result.segments) {
  print('${segment.type}: "${segment.text}" (${segment.start}s - ${segment.end}s)');
}
```

### Highlighting Transcription in UI

```dart
import 'package:flutter/material.dart';
import 'package:offline_transcription/offline_transcription.dart';
import 'package:offline_transcription/src/enhanced_transcription_result.dart';

class TranscriptionDisplay extends StatelessWidget {
  final EnhancedTranscriptionResult result;
  
  const TranscriptionDisplay({Key? key, required this.result}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    // Create a map of rhyme group colors
    final Map<int, Color> rhymeColors = {};
    final List<Color> colorPalette = [
      Colors.red.shade200,
      Colors.blue.shade200,
      Colors.green.shade200,
      Colors.orange.shade200,
      Colors.purple.shade200,
    ];
    
    // Sort annotations by start index
    final annotations = List.of(result.annotations)..sort((a, b) => a.start.compareTo(b.start));
    
    final List<TextSpan> spans = [];
    int currentIndex = 0;
    
    for (final annotation in annotations) {
      // Add text before the annotation
      if (annotation.start > currentIndex) {
        spans.add(TextSpan(
          text: result.text.substring(currentIndex, annotation.start),
          style: const TextStyle(color: Colors.black),
        ));
      }
      
      // Add the annotated text with appropriate styling
      final annotatedText = result.text.substring(annotation.start, annotation.end);
      
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
            style: TextStyle(
              color: Colors.black,
              decoration: TextDecoration.underline,
              decorationColor: Colors.red,
              decorationStyle: TextDecorationStyle.wavy,
              fontStyle: FontStyle.italic,
            ),
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
    if (currentIndex < result.text.length) {
      spans.add(TextSpan(
        text: result.text.substring(currentIndex),
        style: const TextStyle(color: Colors.black),
      ));
    }
    
    return RichText(
      text: TextSpan(children: spans),
    );
  }
}
```

## API Reference

### OfflineTranscription

The main class for interacting with the plugin.

#### Methods

- `Future<void> initialize()`: Initialize the plugin with dictionaries and resources
- `Future<String?> getPlatformVersion()`: Get the platform version
- `Future<String?> transcribeAudioFile(String audioFilePath, {String? modelPath})`: Basic transcription
- `Future<EnhancedTranscriptionResult> transcribeAudioFileEnhanced(String audioFilePath, {...})`: Enhanced transcription with metadata
- `Future<String?> checkPermission()`: Check speech recognition permission
- `Future<String?> requestPermission()`: Request speech recognition permission
- `Future<bool?> downloadModel(String modelUrl, String destinationPath, {String? language})`: Download a model (Android only)
- `List<String> getSupportedLanguages()`: Get all supported languages
- `bool doWordsRhyme(String word1, String word2, {String? language})`: Check if two words rhyme
- `bool isSlang(String word, {String? language})`: Check if a word is slang

#### Properties

- `String currentLanguage`: Get or set the current language for transcription and analysis

### EnhancedTranscriptionResult

A class representing the enhanced transcription result with metadata.

#### Properties

- `String text`: The full transcription text
- `List<TranscriptionAnnotation> annotations`: Annotations for the transcription
- `List<WordInfo> words`: Word-level information
- `List<SegmentInfo> segments`: Segment information (phrases, verses)
- `String language`: The language used for transcription

#### Methods

- `Map<String, dynamic> toJson()`: Convert to a map for JSON serialization
- `factory EnhancedTranscriptionResult.fromJson(Map<String, dynamic> json)`: Create from a JSON map

### TranscriptionAnnotation

A class representing an annotation in the transcription.

#### Properties

- `int start`: Start index in the text
- `int end`: End index in the text
- `String type`: Type of annotation (e.g., "rhyme", "slang")
- `Map<String, dynamic> data`: Additional data for the annotation

### WordInfo

A class representing information about a word in the transcription.

#### Properties

- `String text`: The word text
- `double start`: Start time in seconds
- `double end`: End time in seconds
- `int index`: Index in the words list
- `int startIndex`: Start index in the full text
- `int endIndex`: End index in the full text
- `int? rhymeGroupId`: Rhyme group ID if the word is part of a rhyme group
- `bool isSlang`: Whether the word is slang

### SegmentInfo

A class representing a segment (phrase or verse) in the transcription.

#### Properties

- `String text`: The segment text
- `double start`: Start time in seconds
- `double end`: End time in seconds
- `String type`: Type of segment (e.g., "phrase", "verse")
- `int firstWordIndex`: Index of the first word in the segment
- `int lastWordIndex`: Index of the last word in the segment
- `double duration`: Duration of the segment in seconds

## Language Support

The plugin supports the following languages:

- English (US) - `en_us`
- English (UK) - `en_uk`
- Portuguese (Portugal) - `pt_PT`

## Additional Information

### Dependencies

- Android: Uses [Vosk](https://alphacephei.com/vosk/) for offline speech recognition
- iOS: Uses Apple's [Speech Framework](https://developer.apple.com/documentation/speech) with on-device recognition

### Limitations

- The accuracy of transcription depends on the quality of the audio and the language model
- On Android, you need to download language models which can increase the app size
- On iOS, offline recognition requires iOS 13.0 or later

### Extending the Plugin

To add support for additional languages:

1. Add the language code to the `supportedLanguages` list in `PhoneticDictionary` and `SlangDictionary`
2. Create a phonetic dictionary for the language in the assets directory
3. Create a slang dictionary for the language in the assets directory
4. Update the language selection in the UI

## License

This plugin is licensed under the MIT License - see the LICENSE file for details.
