/// A class to manage slang dictionaries for different languages
class SlangDictionary {
  /// Map of language code to slang dictionary
  static final Map<String, Set<String>> _slangDictionaries = {};

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

  /// Initialize the slang dictionaries
  static Future<void> initialize() async {
    for (final language in supportedLanguages) {
      await _loadSlangDictionary(language);
    }
  }

  /// Load a slang dictionary for a specific language
  static Future<void> _loadSlangDictionary(String language) async {
    final Set<String> slangSet = {};

    // In a real implementation, we would load from assets
    // For this example, we'll create some basic slang dictionaries in memory
    switch (language) {
      case 'en_us':
        slangSet.addAll([
          'ain\'t',
          'gonna',
          'wanna',
          'y\'all',
          'cool',
          'awesome',
          'lit',
          'dope',
          'bae',
          'fam',
          'yeet',
          'flex',
          'salty',
          'savage',
          'woke',
          'basic',
          'ghosting',
          'slay',
          'stan',
          'thirsty',
          'extra',
          'lowkey',
          'highkey',
          'sus',
          'cap',
          'no cap',
          'bet',
          'vibe',
          'simp',
          'bussin',
          'slaps',
          'fire',
          'tea',
          'shade',
          'snatched',
          'wig',
          'periodt',
          'deadass'
        ]);
        break;
      case 'en_uk':
        slangSet.addAll([
          'mate',
          'bloke',
          'quid',
          'chuffed',
          'knackered',
          'cheeky',
          'gutted',
          'dodgy',
          'proper',
          'fit',
          'pissed',
          'naff',
          'skint',
          'gobsmacked',
          'minging',
          'snog',
          'innit',
          'bloody',
          'wanker',
          'bollocks',
          'chav',
          'posh',
          'quid',
          'fiver',
          'tenner',
          'brolly',
          'loo',
          'nosh',
          'peckish',
          'sorted',
          'fancy',
          'rubbish',
          'brilliant',
          'ace',
          'cheers'
        ]);
        break;
      case 'pt_PT':
        slangSet.addAll([
          'fixe',
          'bué',
          'gajo',
          'pá',
          'bacano',
          'chavalo',
          'bazar',
          'curtir',
          'deitar',
          'grana',
          'massa',
          'moca',
          'piço',
          'puto',
          'tuga',
          'bera',
          'cota',
          'gaijo',
          'mano',
          'malta',
          'bué da',
          'ya',
          'tipo',
          'cenas',
          'brutal',
          'altamente',
          'baril',
          'belhote',
          'chunga',
          'giro',
          'porreiro'
        ]);
        break;
    }

    _slangDictionaries[language] = slangSet;
  }

  /// Check if a word is slang
  static bool isSlang(String word, {String? language}) {
    final lang = language ?? _currentLanguage;
    final dictionary = _slangDictionaries[lang];

    if (dictionary == null) {
      throw StateError('Slang dictionary for $lang not loaded. Call initialize() first.');
    }

    return dictionary.contains(word.toLowerCase());
  }

  /// Find all slang words in a list of words
  static List<String> findSlangWords(List<String> words, {String? language}) {
    final lang = language ?? _currentLanguage;
    final slangWords = <String>[];

    for (final word in words) {
      if (isSlang(word, language: lang)) {
        slangWords.add(word);
      }
    }

    return slangWords;
  }
}
