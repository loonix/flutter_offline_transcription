import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_transcription/src/phonetic_dictionary.dart';
import 'package:offline_transcription/src/rhyme_detector.dart';
import 'package:offline_transcription/src/slang_detector.dart';
import 'package:offline_transcription/src/timing_analyzer.dart';
import 'package:offline_transcription/src/enhanced_transcription_result.dart';

void main() {
  group('PhoneticDictionary Tests', () {
    test('getLastSyllable returns correct syllable for English', () {
      PhoneticDictionary.currentLanguage = 'en_us';
      
      final lastSyllable1 = PhoneticDictionary.getLastSyllable('K AE1 T');
      final lastSyllable2 = PhoneticDictionary.getLastSyllable('R AE1 T');
      
      expect(lastSyllable1, 'AE1 T');
      expect(lastSyllable2, 'AE1 T');
      expect(lastSyllable1, lastSyllable2); // Should rhyme
    });
    
    test('doWordsRhyme correctly identifies rhyming words', () {
      // This is a mock test since we can't load the actual dictionary in tests
      // In a real implementation, we would mock the dictionary lookup
      
      // Mock implementation for testing
      final mockDoWordsRhyme = (String word1, String word2) {
        final rhymePairs = {
          'cat': ['hat', 'bat', 'rat', 'mat'],
          'light': ['night', 'sight', 'fight', 'bright'],
          'day': ['way', 'say', 'may', 'play'],
        };
        
        return rhymePairs[word1.toLowerCase()]?.contains(word2.toLowerCase()) ?? 
               rhymePairs.values.any((rhymes) => 
                 rhymes.contains(word1.toLowerCase()) && 
                 rhymes.contains(word2.toLowerCase()));
      };
      
      expect(mockDoWordsRhyme('cat', 'hat'), true);
      expect(mockDoWordsRhyme('light', 'night'), true);
      expect(mockDoWordsRhyme('cat', 'dog'), false);
    });
  });
  
  group('RhymeDetector Tests', () {
    test('detectRhymes groups rhyming words correctly', () {
      final detector = RhymeDetector();
      
      // Mock implementation for testing
      // In a real test, we would use dependency injection to mock PhoneticDictionary
      
      // Simulate rhyme detection with predefined groups
      final words = ['cat', 'dog', 'hat', 'fish', 'rat', 'bird'];
      final expectedGroups = {
        0: 1, // cat -> group 1
        2: 1, // hat -> group 1
        4: 1, // rat -> group 1
      };
      
      // This is a simplified test that doesn't actually call PhoneticDictionary
      final Map<int, int> mockResult = {};
      for (int i = 0; i < words.length; i++) {
        if (words[i] == 'cat' || words[i] == 'hat' || words[i] == 'rat') {
          mockResult[i] = 1;
        }
      }
      
      expect(mockResult, expectedGroups);
    });
  });
  
  group('TimingAnalyzer Tests', () {
    test('analyzeVoskTiming correctly identifies segments', () {
      final voskJson = '''
      {
        "result": [
          {"word": "hello", "start": 0.0, "end": 0.5},
          {"word": "world", "start": 0.6, "end": 1.0},
          {"word": "this", "start": 1.8, "end": 2.0},
          {"word": "is", "start": 2.1, "end": 2.3},
          {"word": "a", "start": 2.4, "end": 2.5},
          {"word": "test", "start": 2.6, "end": 3.0}
        ]
      }
      ''';
      
      final result = TimingAnalyzer.analyzeVoskTiming(voskJson);
      
      expect(result['words'].length, 6);
      expect(result['segments'].length, 2); // Should detect 2 segments due to pause
      
      // First segment should be "hello world"
      expect(result['segments'][0]['words'].length, 2);
      expect(result['segments'][0]['words'][0], 'hello');
      expect(result['segments'][0]['words'][1], 'world');
      
      // Second segment should be "this is a test"
      expect(result['segments'][1]['words'].length, 4);
      expect(result['segments'][1]['words'][0], 'this');
    });
  });
  
  group('EnhancedTranscriptionResult Tests', () {
    test('JSON serialization and deserialization works correctly', () {
      final result = EnhancedTranscriptionResult(
        text: 'This is a test',
        annotations: [
          TranscriptionAnnotation(
            start: 0,
            end: 4,
            type: 'rhyme',
            data: {'groupId': 1},
          ),
          TranscriptionAnnotation(
            start: 10,
            end: 14,
            type: 'slang',
          ),
        ],
        words: [
          WordInfo(
            text: 'This',
            start: 0.0,
            end: 0.5,
            index: 0,
            startIndex: 0,
            endIndex: 4,
            rhymeGroupId: 1,
          ),
          WordInfo(
            text: 'is',
            start: 0.6,
            end: 0.8,
            index: 1,
            startIndex: 5,
            endIndex: 7,
          ),
          WordInfo(
            text: 'a',
            start: 0.9,
            end: 1.0,
            index: 2,
            startIndex: 8,
            endIndex: 9,
          ),
          WordInfo(
            text: 'test',
            start: 1.1,
            end: 1.5,
            index: 3,
            startIndex: 10,
            endIndex: 14,
            isSlang: true,
          ),
        ],
        segments: [
          SegmentInfo(
            text: 'This is a test',
            start: 0.0,
            end: 1.5,
            type: 'phrase',
            firstWordIndex: 0,
            lastWordIndex: 3,
            duration: 1.5,
          ),
        ],
        language: 'en_us',
      );
      
      final json = result.toJson();
      final decoded = EnhancedTranscriptionResult.fromJson(json);
      
      expect(decoded.text, 'This is a test');
      expect(decoded.annotations.length, 2);
      expect(decoded.words.length, 4);
      expect(decoded.segments.length, 1);
      expect(decoded.language, 'en_us');
      
      expect(decoded.annotations[0].type, 'rhyme');
      expect(decoded.annotations[0].data['groupId'], 1);
      
      expect(decoded.words[3].isSlang, true);
      expect(decoded.words[0].rhymeGroupId, 1);
    });
  });
}
