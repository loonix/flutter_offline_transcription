import 'dart:convert';

/// A class to analyze timing in audio transcriptions
class TimingAnalyzer {
  /// Default pause threshold for phrase detection (in seconds)
  static const double defaultPhraseThreshold = 0.5;
  
  /// Default pause threshold for verse detection (in seconds)
  static const double defaultVerseThreshold = 1.0;
  
  /// Analyze timing data from Vosk JSON output to detect phrases and verses
  /// Returns a map with segment information
  static Map<String, dynamic> analyzeVoskTiming(String voskJson, {
    double phraseThreshold = defaultPhraseThreshold,
    double verseThreshold = defaultVerseThreshold,
  }) {
    final Map<String, dynamic> result = {
      'segments': <Map<String, dynamic>>[],
      'words': <Map<String, dynamic>>[],
    };
    
    try {
      final Map<String, dynamic> jsonData = json.decode(voskJson);
      
      if (!jsonData.containsKey('result')) {
        return result;
      }
      
      final List<dynamic> words = jsonData['result'];
      if (words.isEmpty) {
        return result;
      }
      
      // Process word timing data
      final List<Map<String, dynamic>> processedWords = [];
      final List<Map<String, dynamic>> segments = [];
      
      Map<String, dynamic>? currentSegment;
      double? lastEndTime;
      
      for (int i = 0; i < words.length; i++) {
        final word = words[i];
        final String text = word['word'];
        final double start = word['start'].toDouble();
        final double end = word['end'].toDouble();
        
        // Add word with timing info
        final Map<String, dynamic> wordInfo = {
          'word': text,
          'start': start,
          'end': end,
          'index': i,
        };
        processedWords.add(wordInfo);
        
        // Check for pauses between words
        if (lastEndTime != null) {
          final double pauseDuration = start - lastEndTime;
          
          // Detect verse (long pause)
          if (pauseDuration >= verseThreshold) {
            if (currentSegment != null) {
              currentSegment['end'] = lastEndTime;
              currentSegment['type'] = 'verse';
              segments.add(currentSegment);
            }
            
            currentSegment = {
              'start': start,
              'firstWordIndex': i,
              'words': [text],
            };
          }
          // Detect phrase (medium pause)
          else if (pauseDuration >= phraseThreshold) {
            if (currentSegment != null) {
              currentSegment['end'] = lastEndTime;
              currentSegment['type'] = 'phrase';
              segments.add(currentSegment);
            }
            
            currentSegment = {
              'start': start,
              'firstWordIndex': i,
              'words': [text],
            };
          }
          // Continue current segment
          else if (currentSegment != null) {
            currentSegment['words'].add(text);
          }
        }
        // First word in transcription
        else if (currentSegment == null) {
          currentSegment = {
            'start': start,
            'firstWordIndex': i,
            'words': [text],
          };
        }
        
        lastEndTime = end;
      }
      
      // Add the last segment
      if (currentSegment != null) {
        currentSegment['end'] = lastEndTime;
        currentSegment['type'] = 'phrase'; // Default to phrase for the last segment
        segments.add(currentSegment);
      }
      
      // Calculate additional segment properties
      for (final segment in segments) {
        segment['text'] = segment['words'].join(' ');
        segment['duration'] = segment['end'] - segment['start'];
        segment['lastWordIndex'] = segment['firstWordIndex'] + segment['words'].length - 1;
      }
      
      result['segments'] = segments;
      result['words'] = processedWords;
    } catch (e) {
      print('Error analyzing timing data: $e');
    }
    
    return result;
  }
  
  /// Analyze timing data from iOS Speech framework
  /// Note: iOS Speech framework doesn't provide detailed word timing by default
  /// This is a simplified version that estimates timing based on word count
  static Map<String, dynamic> analyzeIosTiming(String transcription, double totalDuration, {
    double phraseThreshold = defaultPhraseThreshold,
    double verseThreshold = defaultVerseThreshold,
  }) {
    final Map<String, dynamic> result = {
      'segments': <Map<String, dynamic>>[],
      'words': <Map<String, dynamic>>[],
    };
    
    try {
      final List<String> words = transcription.split(' ');
      if (words.isEmpty) {
        return result;
      }
      
      // Estimate average word duration
      final double avgWordDuration = totalDuration / words.length;
      
      // Process words with estimated timing
      final List<Map<String, dynamic>> processedWords = [];
      double currentTime = 0.0;
      
      for (int i = 0; i < words.length; i++) {
        final String word = words[i];
        final double start = currentTime;
        // Estimate word duration based on length (simple heuristic)
        final double wordDuration = avgWordDuration * (0.5 + (word.length / 5));
        final double end = start + wordDuration;
        
        final Map<String, dynamic> wordInfo = {
          'word': word,
          'start': start,
          'end': end,
          'index': i,
        };
        processedWords.add(wordInfo);
        
        currentTime = end;
      }
      
      // For iOS, we'll use a simpler approach based on punctuation
      // since we don't have accurate timing data
      final List<Map<String, dynamic>> segments = [];
      Map<String, dynamic>? currentSegment;
      
      for (int i = 0; i < processedWords.length; i++) {
        final Map<String, dynamic> wordInfo = processedWords[i];
        final String word = wordInfo['word'];
        
        // Check for punctuation that might indicate phrase or verse boundaries
        final bool isPhraseBoundary = word.contains('.') || word.contains(',') || 
                                      word.contains(';') || word.contains(':');
        final bool isVerseBoundary = word.contains('!') || word.contains('?') || 
                                     word.contains('.') && (i < processedWords.length - 1 && 
                                     processedWords[i + 1]['word'][0] == processedWords[i + 1]['word'][0].toUpperCase());
        
        if (currentSegment == null) {
          currentSegment = {
            'start': wordInfo['start'],
            'firstWordIndex': i,
            'words': [word],
          };
        } else {
          currentSegment['words'].add(word);
        }
        
        if (isVerseBoundary || isPhraseBoundary || i == processedWords.length - 1) {
          currentSegment['end'] = wordInfo['end'];
          currentSegment['type'] = isVerseBoundary ? 'verse' : 'phrase';
          segments.add(currentSegment);
          
          if (i < processedWords.length - 1) {
            currentSegment = null;
          }
        }
      }
      
      // Calculate additional segment properties
      for (final segment in segments) {
        segment['text'] = segment['words'].join(' ');
        segment['duration'] = segment['end'] - segment['start'];
        segment['lastWordIndex'] = segment['firstWordIndex'] + segment['words'].length - 1;
      }
      
      result['segments'] = segments;
      result['words'] = processedWords;
    } catch (e) {
      print('Error analyzing iOS timing data: $e');
    }
    
    return result;
  }
}
