import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:offline_transcription/src/slang_dictionary.dart';

import 'src/enhanced_transcription_result.dart';
import 'src/phonetic_dictionary.dart';
import 'src/rhyme_detector.dart';
import 'src/slang_detector.dart';
import 'src/timing_analyzer.dart';
import 'offline_transcription_platform_interface.dart';

/// A Flutter plugin for offline audio transcription on Android and iOS with enhanced features.
class OfflineTranscription {
  /// The current language for transcription and analysis
  String _currentLanguage = 'en_us';

  /// Get the current language
  String get currentLanguage => _currentLanguage;

  /// Set the current language
  set currentLanguage(String language) {
    if (PhoneticDictionary.supportedLanguages.contains(language)) {
      _currentLanguage = language;
      PhoneticDictionary.currentLanguage = language;
    } else {
      throw ArgumentError('Unsupported language: $language. Supported languages are: ${PhoneticDictionary.supportedLanguages}');
    }
  }

  /// Initialize the plugin with dictionaries and resources
  Future<void> initialize() async {
    await PhoneticDictionary.initialize();
    await SlangDictionary.initialize();
  }

  /// Returns the current platform version.
  Future<String?> getPlatformVersion() {
    return OfflineTranscriptionPlatform.instance.getPlatformVersion();
  }

  /// Transcribes an audio file at the given path with basic functionality.
  ///
  /// [audioFilePath] is the absolute path to the audio file to transcribe.
  /// [modelPath] is the absolute path to the model directory (Android only).
  ///
  /// Returns the transcribed text as a string.
  Future<String?> transcribeAudioFile(String audioFilePath, {String? modelPath}) {
    return OfflineTranscriptionPlatform.instance.transcribeAudioFile(audioFilePath, modelPath: modelPath);
  }

  /// Transcribes an audio file and returns metadata.
  ///
  /// [audioFilePath] is the absolute path to the audio file to transcribe.
  /// [modelPath] is the absolute path to the model directory (Android only).
  /// [language] is the language code to use for transcription.
  /// [forceTranscription] forces transcription attempt even on files that appear to be music.
  ///
  /// Returns the transcribed text with metadata as a JSON string.
  Future<String?> transcribeAudioFileWithMetadata(String audioFilePath, {String? modelPath, String? language, bool forceTranscription = false}) {
    return OfflineTranscriptionPlatform.instance.transcribeAudioFileWithMetadata(
      audioFilePath,
      modelPath: modelPath,
      language: language ?? _currentLanguage,
      forceTranscription: forceTranscription,
    );
  }

  /// Transcribes an audio file with enhanced features including rhyme detection,
  /// timing analysis, and slang detection.
  ///
  /// [audioFilePath] is the absolute path to the audio file to transcribe.
  /// [modelPath] is the absolute path to the model directory (Android only).
  /// [language] is the language code to use for transcription and analysis.
  /// [detectRhymes] whether to detect and group rhyming words.
  /// [detectSlang] whether to detect slang words.
  /// [analyzeTiming] whether to analyze timing for phrase/verse detection.
  /// [totalDuration] the total duration of the audio file (required for iOS timing analysis).
  ///
  /// Returns an EnhancedTranscriptionResult with the transcription and metadata.
  Future<EnhancedTranscriptionResult> transcribeAudioFileEnhanced(
    String audioFilePath, {
    String? modelPath,
    String? language,
    bool detectRhymes = true,
    bool detectSlang = true,
    bool analyzeTiming = true,
    double? totalDuration,
  }) async {
    final lang = language ?? _currentLanguage;

    // Get the basic transcription
    final rawTranscription = await OfflineTranscriptionPlatform.instance.transcribeAudioFileWithMetadata(
      audioFilePath,
      modelPath: modelPath,
      language: lang,
    );

    if (rawTranscription == null || rawTranscription.isEmpty) {
      throw Exception('Transcription failed or returned empty result');
    }

    // Parse the raw transcription
    Map<String, dynamic> transcriptionData;
    try {
      transcriptionData = json.decode(rawTranscription);
    } catch (e) {
      // If not JSON, treat as plain text
      transcriptionData = {
        'text': rawTranscription,
        'words': rawTranscription.split(' ').map((word) => {'word': word}).toList(),
      };
    }

    final String transcriptionText = transcriptionData['text'] ?? '';
    final List<dynamic> rawWords = transcriptionData['words'] ?? [];

    // Extract words
    final List<String> words = rawWords.map((w) => w['word'].toString()).toList();

    // Process timing data
    Map<String, dynamic> timingData = {};
    if (analyzeTiming) {
      if (defaultTargetPlatform == TargetPlatform.android) {
        timingData = TimingAnalyzer.analyzeVoskTiming(rawTranscription);
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        if (totalDuration == null) {
          throw ArgumentError('totalDuration is required for iOS timing analysis');
        }
        timingData = TimingAnalyzer.analyzeIosTiming(transcriptionText, totalDuration);
      }
    }

    // Detect rhymes
    Map<int, int> rhymeGroups = {};
    if (detectRhymes) {
      final rhymeDetector = RhymeDetector();
      rhymeGroups = rhymeDetector.detectRhymes(words, language: lang);
    }

    // Detect slang
    Map<int, bool> slangWords = {};
    if (detectSlang) {
      slangWords = SlangDetector.detectSlang(words, language: lang);
    }

    // Build word info list
    final List<WordInfo> wordInfoList = [];
    int currentTextIndex = 0;

    for (int i = 0; i < words.length; i++) {
      final String word = words[i];

      // Find word in the full text
      final int startIndex = transcriptionText.indexOf(word, currentTextIndex);
      final int endIndex = startIndex + word.length;
      currentTextIndex = endIndex;

      // Get timing data
      double start = 0.0;
      double end = 0.0;

      if (timingData.containsKey('words') && i < timingData['words'].length) {
        start = timingData['words'][i]['start'];
        end = timingData['words'][i]['end'];
      }

      // Create word info
      final WordInfo wordInfo = WordInfo(
        text: word,
        start: start,
        end: end,
        index: i,
        startIndex: startIndex,
        endIndex: endIndex,
        rhymeGroupId: rhymeGroups[i],
        isSlang: slangWords[i] ?? false,
      );

      wordInfoList.add(wordInfo);
    }

    // Build segment info list
    final List<SegmentInfo> segmentInfoList = [];

    if (timingData.containsKey('segments')) {
      for (final segment in timingData['segments']) {
        final SegmentInfo segmentInfo = SegmentInfo(
          text: segment['text'],
          start: segment['start'],
          end: segment['end'],
          type: segment['type'],
          firstWordIndex: segment['firstWordIndex'],
          lastWordIndex: segment['lastWordIndex'],
          duration: segment['duration'],
        );

        segmentInfoList.add(segmentInfo);
      }
    }

    // Build annotations list
    final List<TranscriptionAnnotation> annotations = [];

    // Add rhyme annotations
    final Map<int, List<int>> rhymeGroupToIndices = {};
    for (final entry in rhymeGroups.entries) {
      final int wordIndex = entry.key;
      final int groupId = entry.value;

      if (!rhymeGroupToIndices.containsKey(groupId)) {
        rhymeGroupToIndices[groupId] = [];
      }

      rhymeGroupToIndices[groupId]!.add(wordIndex);
    }

    for (final entry in rhymeGroupToIndices.entries) {
      final int groupId = entry.key;
      final List<int> wordIndices = entry.value;

      for (final wordIndex in wordIndices) {
        if (wordIndex < wordInfoList.length) {
          final WordInfo wordInfo = wordInfoList[wordIndex];

          final TranscriptionAnnotation annotation = TranscriptionAnnotation(
            start: wordInfo.startIndex,
            end: wordInfo.endIndex,
            type: 'rhyme',
            data: {'groupId': groupId},
          );

          annotations.add(annotation);
        }
      }
    }

    // Add slang annotations
    for (final entry in slangWords.entries) {
      final int wordIndex = entry.key;
      final bool isSlang = entry.value;

      if (isSlang && wordIndex < wordInfoList.length) {
        final WordInfo wordInfo = wordInfoList[wordIndex];

        final TranscriptionAnnotation annotation = TranscriptionAnnotation(
          start: wordInfo.startIndex,
          end: wordInfo.endIndex,
          type: 'slang',
        );

        annotations.add(annotation);
      }
    }

    // Add segment annotations
    for (final segment in segmentInfoList) {
      if (segment.firstWordIndex < wordInfoList.length && segment.lastWordIndex < wordInfoList.length) {
        final WordInfo firstWord = wordInfoList[segment.firstWordIndex];
        final WordInfo lastWord = wordInfoList[segment.lastWordIndex];

        final TranscriptionAnnotation annotation = TranscriptionAnnotation(
          start: firstWord.startIndex,
          end: lastWord.endIndex,
          type: segment.type,
          data: {
            'start': segment.start,
            'end': segment.end,
            'duration': segment.duration,
          },
        );

        annotations.add(annotation);
      }
    }

    // Create the enhanced result
    return EnhancedTranscriptionResult(
      text: transcriptionText,
      annotations: annotations,
      words: wordInfoList,
      segments: segmentInfoList,
      language: lang,
    );
  }

  /// Checks if speech recognition permission is granted.
  ///
  /// Returns a string representing the permission status:
  /// - 'authorized': Permission granted
  /// - 'denied': Permission denied
  /// - 'restricted': Permission restricted
  /// - 'notDetermined': Permission not determined
  /// - 'unknown': Unknown status
  Future<String?> checkPermission() {
    return OfflineTranscriptionPlatform.instance.checkPermission();
  }

  /// Requests speech recognition permission.
  ///
  /// Returns a string representing the permission status after the request:
  /// - 'authorized': Permission granted
  /// - 'denied': Permission denied
  /// - 'restricted': Permission restricted
  /// - 'notDetermined': Permission not determined
  /// - 'unknown': Unknown status
  Future<String?> requestPermission() {
    return OfflineTranscriptionPlatform.instance.requestPermission();
  }

  /// Downloads a model for offline speech recognition (Android only).
  ///
  /// [modelUrl] is the URL to download the model from.
  /// [destinationPath] is the absolute path where the model should be saved.
  /// [language] is the language code for the model.
  ///
  /// Returns true if the download was successful, false otherwise.
  Future<bool?> downloadModel(String modelUrl, String destinationPath, {String? language}) {
    return OfflineTranscriptionPlatform.instance.downloadModel(
      modelUrl,
      destinationPath,
      language: language ?? _currentLanguage,
    );
  }

  /// Get all supported languages
  List<String> getSupportedLanguages() {
    return PhoneticDictionary.supportedLanguages;
  }

  /// Check if two words rhyme
  bool doWordsRhyme(String word1, String word2, {String? language}) {
    return PhoneticDictionary.doWordsRhyme(word1, word2, language: language ?? _currentLanguage);
  }

  /// Check if a word is slang
  bool isSlang(String word, {String? language}) {
    return SlangDetector.isSlang(word, language: language ?? _currentLanguage);
  }
}
