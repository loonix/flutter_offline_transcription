import 'package:flutter/services.dart';

/// A class to manage phonetic dictionaries for different languages
class PhoneticDictionary {
  /// Map of language code to dictionary
  static final Map<String, Map<String, String>> _dictionaries = {};

  /// Supported language codes
  static const List<String> supportedLanguages = ['en_us', 'en_uk', 'pt_PT'];

  /// Current language code
  static String _currentLanguage = 'en_us';

  /// Get the current language code
  static String get currentLanguage => _currentLanguage;

  /// Set the current language code
  static set currentLanguage(String language) {
    if (supportedLanguages.contains(language)) {
      _currentLanguage = language;
    } else {
      throw ArgumentError('Unsupported language: $language. Supported languages are: $supportedLanguages');
    }
  }

  /// Initialize the dictionaries
  static Future<void> initialize() async {
    for (final language in supportedLanguages) {
      await _loadDictionary(language);
    }
  }

  /// Load a dictionary for a specific language
  static Future<void> _loadDictionary(String language) async {
    final Map<String, String> dictionary = {};

    String dictionaryPath;
    if (language.startsWith('en')) {
      dictionaryPath = 'assets/dictionaries/$language/cmudict.dict';
    } else if (language == 'pt_PT') {
      dictionaryPath = 'assets/dictionaries/$language/ptdict.dict';
    } else {
      throw ArgumentError('Unsupported language: $language');
    }

    try {
      // Load from assets
      final String content = await rootBundle.loadString(dictionaryPath);
      final List<String> lines = content.split('\n');

      for (final line in lines) {
        if (line.trim().isEmpty || line.startsWith(';;;')) continue;

        final parts = line.trim().split('  ');
        if (parts.length >= 2) {
          final word = parts[0].toLowerCase();
          final pronunciation = parts[1];
          dictionary[word] = pronunciation;
        }
      }

      _dictionaries[language] = dictionary;
    } catch (e) {
      print('Error loading dictionary for $language: $e');
      // Create an empty dictionary if loading fails
      _dictionaries[language] = {};
    }
  }

  /// Get the phonetic representation of a word
  static String getPhonetic(String word, {String? language}) {
    final lang = language ?? _currentLanguage;
    final dictionary = _dictionaries[lang];

    if (dictionary == null) {
      throw StateError('Dictionary for $lang not loaded. Call initialize() first.');
    }

    return dictionary[word.toLowerCase()] ?? '';
  }

  /// Get the last syllable of a phonetic representation
  static String getLastSyllable(String phonetic) {
    final parts = phonetic.split(' ');
    if (parts.isEmpty) return '';

    // For English (CMU dict), we consider the last vowel and everything after it
    if (_currentLanguage.startsWith('en')) {
      final vowels = ['AA', 'AE', 'AH', 'AO', 'AW', 'AY', 'EH', 'ER', 'EY', 'IH', 'IY', 'OW', 'OY', 'UH', 'UW'];

      int lastVowelIndex = -1;
      for (int i = parts.length - 1; i >= 0; i--) {
        final phoneme = parts[i].split('0')[0].split('1')[0].split('2')[0]; // Remove stress markers
        if (vowels.contains(phoneme)) {
          lastVowelIndex = i;
          break;
        }
      }

      if (lastVowelIndex >= 0) {
        return parts.sublist(lastVowelIndex).join(' ');
      }
    }
    // For Portuguese, we use a simpler approach
    else if (_currentLanguage == 'pt_PT') {
      // Take the last 2 phonemes or the whole thing if it's shorter
      return parts.length > 2 ? parts.sublist(parts.length - 2).join(' ') : phonetic;
    }

    return parts.last; // Fallback to just the last phoneme
  }

  /// Check if two words rhyme
  static bool doWordsRhyme(String word1, String word2, {String? language}) {
    final lang = language ?? _currentLanguage;

    final phonetic1 = getPhonetic(word1, language: lang);
    final phonetic2 = getPhonetic(word2, language: lang);

    if (phonetic1.isEmpty || phonetic2.isEmpty) return false;

    final lastSyllable1 = getLastSyllable(phonetic1);
    final lastSyllable2 = getLastSyllable(phonetic2);

    return lastSyllable1 == lastSyllable2 && lastSyllable1.isNotEmpty;
  }

  /// Find rhyming words for a given word
  static List<String> findRhymes(String word, List<String> wordList, {String? language}) {
    final lang = language ?? _currentLanguage;
    final phonetic = getPhonetic(word, language: lang);

    if (phonetic.isEmpty) return [];

    final lastSyllable = getLastSyllable(phonetic);
    final rhymes = <String>[];

    for (final candidate in wordList) {
      if (candidate.toLowerCase() == word.toLowerCase()) continue;

      final candidatePhonetic = getPhonetic(candidate, language: lang);
      if (candidatePhonetic.isEmpty) continue;

      final candidateLastSyllable = getLastSyllable(candidatePhonetic);

      if (candidateLastSyllable == lastSyllable) {
        rhymes.add(candidate);
      }
    }

    return rhymes;
  }
}
