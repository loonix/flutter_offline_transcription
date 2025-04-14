import 'slang_dictionary.dart';

/// A class to detect slang words in transcriptions
class SlangDetector {
  /// Detect slang words in a list of words
  /// Returns a map of word indices to boolean indicating if the word is slang
  static Map<int, bool> detectSlang(List<String> words, {String? language}) {
    final Map<int, bool> slangIndices = {};
    
    for (int i = 0; i < words.length; i++) {
      final word = words[i];
      if (SlangDictionary.isSlang(word, language: language)) {
        slangIndices[i] = true;
      }
    }
    
    return slangIndices;
  }
  
  /// Get all slang words from a list of words
  static List<String> getSlangWords(List<String> words, {String? language}) {
    return SlangDictionary.findSlangWords(words, language: language);
  }
  
  /// Check if a specific word is slang
  static bool isSlang(String word, {String? language}) {
    return SlangDictionary.isSlang(word, language: language);
  }
}
