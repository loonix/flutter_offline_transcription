# Changelog

## Version 1.0.0

### New Features

- **Rhyme Detection**
  - Added phonetic dictionaries for en_us, en_uk, and pt_PT
  - Implemented rhyme detection algorithm using phonetic representations
  - Added rhyme group identification and metadata

- **Transcription Highlighting**
  - Added metadata (start/end indices) for notable sections
  - Implemented annotation system for highlighting different features
  - Added support for RichText styling based on metadata

- **Verse/Phrase Ending Detection**
  - Added timing analysis for pause detection
  - Implemented segmentation based on pause thresholds
  - Added segment markers in the output

- **Slang Detection**
  - Added slang dictionaries for supported languages
  - Implemented slang word detection and tagging
  - Added metadata for slang words in the output

- **Enhanced Language Support**
  - Added support for en_us, en_uk, and pt_PT
  - Implemented language selection in the API
  - Added language-specific processing for each feature

### API Enhancements

- Added `transcribeAudioFileEnhanced` method for enhanced transcription
- Added `EnhancedTranscriptionResult` class for structured output
- Added utility methods for rhyme and slang detection
- Updated platform interfaces for metadata support

### Example App

- Added language selection dropdown
- Implemented highlighting for rhymes, slang, and segments
- Added detailed metadata display
- Added audio playback with waveform visualization

### Documentation

- Updated README with comprehensive documentation
- Added code examples for all new features
- Added API reference for new classes and methods
- Added guidance for UI implementation with highlighting
