import 'phonetic_dictionary.dart';

/// A class to detect and group rhyming words in transcriptions
class RhymeDetector {
  /// Map of rhyme group IDs to words in that group
  final Map<int, List<String>> _rhymeGroups = {};

  /// Map of words to their rhyme group IDs
  final Map<String, int> _wordToGroupId = {};

  /// Current rhyme group ID counter
  int _currentGroupId = 1;

  /// Get all rhyme groups
  Map<int, List<String>> get rhymeGroups => Map.unmodifiable(_rhymeGroups);

  /// Get the rhyme group ID for a word
  int? getRhymeGroupId(String word) {
    return _wordToGroupId[word.toLowerCase()];
  }

  /// Process a list of words to detect rhymes
  /// Returns a map of word indices to rhyme group IDs
  Map<int, int> detectRhymes(List<String> words, {String? language}) {
    // Reset state for new detection
    _rhymeGroups.clear();
    _wordToGroupId.clear();
    _currentGroupId = 1;

    final Map<int, int> wordIndexToGroupId = {};

    // First pass: identify all words and their potential rhyme groups
    for (int i = 0; i < words.length; i++) {
      final word = words[i].toLowerCase();

      // Skip words that are too short or already processed
      if (word.length < 2 || _wordToGroupId.containsKey(word)) continue;

      bool foundRhyme = false;

      // Check if this word rhymes with any existing group
      for (final entry in _rhymeGroups.entries) {
        final groupId = entry.key;
        final groupWords = entry.value;

        // Check if the word rhymes with the first word in the group
        if (PhoneticDictionary.doWordsRhyme(word, groupWords.first, language: language)) {
          // Add to existing group
          groupWords.add(word);
          _wordToGroupId[word] = groupId;
          wordIndexToGroupId[i] = groupId;
          foundRhyme = true;
          break;
        }
      }

      // If no rhyme found, create a new group if the word has a phonetic representation
      if (!foundRhyme && PhoneticDictionary.getPhonetic(word, language: language).isNotEmpty) {
        final groupId = _currentGroupId++;
        _rhymeGroups[groupId] = [word];
        _wordToGroupId[word] = groupId;
        wordIndexToGroupId[i] = groupId;
      }
    }

    // Second pass: clean up groups with only one word (no actual rhymes)
    final groupsToRemove = <int>[];
    for (final entry in _rhymeGroups.entries) {
      if (entry.value.length < 2) {
        groupsToRemove.add(entry.key);

        // Remove the word from the word-to-group mapping
        final word = entry.value.first;
        _wordToGroupId.remove(word);

        // Remove from the index mapping
        wordIndexToGroupId.removeWhere((key, value) => value == entry.key);
      }
    }

    // Remove the single-word groups
    for (final groupId in groupsToRemove) {
      _rhymeGroups.remove(groupId);
    }

    return wordIndexToGroupId;
  }

  /// Get all words that rhyme with a specific word
  List<String> getRhymingWords(String word) {
    final groupId = _wordToGroupId[word.toLowerCase()];
    if (groupId == null) return [];

    final group = _rhymeGroups[groupId];
    if (group == null) return [];

    return group.where((w) => w.toLowerCase() != word.toLowerCase()).toList();
  }

  /// Check if a word is part of a rhyme group
  bool isRhyming(String word) {
    return _wordToGroupId.containsKey(word.toLowerCase());
  }
}
