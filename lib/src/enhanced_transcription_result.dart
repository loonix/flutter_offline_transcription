/// A class representing the enhanced transcription result with metadata
class EnhancedTranscriptionResult {
  /// The full transcription text
  final String text;
  
  /// Annotations for the transcription
  final List<TranscriptionAnnotation> annotations;
  
  /// Word-level information
  final List<WordInfo> words;
  
  /// Segment information (phrases, verses)
  final List<SegmentInfo> segments;
  
  /// The language used for transcription
  final String language;

  EnhancedTranscriptionResult({
    required this.text,
    required this.annotations,
    required this.words,
    required this.segments,
    required this.language,
  });
  
  /// Convert to a map for JSON serialization
  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'annotations': annotations.map((a) => a.toJson()).toList(),
      'words': words.map((w) => w.toJson()).toList(),
      'segments': segments.map((s) => s.toJson()).toList(),
      'language': language,
    };
  }
  
  /// Create from a JSON map
  factory EnhancedTranscriptionResult.fromJson(Map<String, dynamic> json) {
    return EnhancedTranscriptionResult(
      text: json['text'],
      annotations: (json['annotations'] as List)
          .map((a) => TranscriptionAnnotation.fromJson(a))
          .toList(),
      words: (json['words'] as List)
          .map((w) => WordInfo.fromJson(w))
          .toList(),
      segments: (json['segments'] as List)
          .map((s) => SegmentInfo.fromJson(s))
          .toList(),
      language: json['language'],
    );
  }
}

/// A class representing an annotation in the transcription
class TranscriptionAnnotation {
  /// Start index in the text
  final int start;
  
  /// End index in the text
  final int end;
  
  /// Type of annotation (e.g., "rhyme", "slang")
  final String type;
  
  /// Additional data for the annotation
  final Map<String, dynamic> data;

  TranscriptionAnnotation({
    required this.start,
    required this.end,
    required this.type,
    this.data = const {},
  });
  
  /// Convert to a map for JSON serialization
  Map<String, dynamic> toJson() {
    return {
      'start': start,
      'end': end,
      'type': type,
      'data': data,
    };
  }
  
  /// Create from a JSON map
  factory TranscriptionAnnotation.fromJson(Map<String, dynamic> json) {
    return TranscriptionAnnotation(
      start: json['start'],
      end: json['end'],
      type: json['type'],
      data: json['data'] ?? {},
    );
  }
}

/// A class representing information about a word in the transcription
class WordInfo {
  /// The word text
  final String text;
  
  /// Start time in seconds
  final double start;
  
  /// End time in seconds
  final double end;
  
  /// Index in the words list
  final int index;
  
  /// Start index in the full text
  final int startIndex;
  
  /// End index in the full text
  final int endIndex;
  
  /// Rhyme group ID if the word is part of a rhyme group
  final int? rhymeGroupId;
  
  /// Whether the word is slang
  final bool isSlang;

  WordInfo({
    required this.text,
    required this.start,
    required this.end,
    required this.index,
    required this.startIndex,
    required this.endIndex,
    this.rhymeGroupId,
    this.isSlang = false,
  });
  
  /// Convert to a map for JSON serialization
  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'start': start,
      'end': end,
      'index': index,
      'startIndex': startIndex,
      'endIndex': endIndex,
      'rhymeGroupId': rhymeGroupId,
      'isSlang': isSlang,
    };
  }
  
  /// Create from a JSON map
  factory WordInfo.fromJson(Map<String, dynamic> json) {
    return WordInfo(
      text: json['text'],
      start: json['start'],
      end: json['end'],
      index: json['index'],
      startIndex: json['startIndex'],
      endIndex: json['endIndex'],
      rhymeGroupId: json['rhymeGroupId'],
      isSlang: json['isSlang'] ?? false,
    );
  }
}

/// A class representing a segment (phrase or verse) in the transcription
class SegmentInfo {
  /// The segment text
  final String text;
  
  /// Start time in seconds
  final double start;
  
  /// End time in seconds
  final double end;
  
  /// Type of segment (e.g., "phrase", "verse")
  final String type;
  
  /// Index of the first word in the segment
  final int firstWordIndex;
  
  /// Index of the last word in the segment
  final int lastWordIndex;
  
  /// Duration of the segment in seconds
  final double duration;

  SegmentInfo({
    required this.text,
    required this.start,
    required this.end,
    required this.type,
    required this.firstWordIndex,
    required this.lastWordIndex,
    required this.duration,
  });
  
  /// Convert to a map for JSON serialization
  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'start': start,
      'end': end,
      'type': type,
      'firstWordIndex': firstWordIndex,
      'lastWordIndex': lastWordIndex,
      'duration': duration,
    };
  }
  
  /// Create from a JSON map
  factory SegmentInfo.fromJson(Map<String, dynamic> json) {
    return SegmentInfo(
      text: json['text'],
      start: json['start'],
      end: json['end'],
      type: json['type'],
      firstWordIndex: json['firstWordIndex'],
      lastWordIndex: json['lastWordIndex'],
      duration: json['duration'],
    );
  }
}
