import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'offline_transcription_method_channel.dart';

/// The interface that implementations of offline_transcription must implement.
///
/// Platform implementations should extend this class rather than implement it as
/// `offline_transcription` does not consider newly added methods to be breaking changes.
/// Extending this class (using `extends`) ensures that the subclass will get the
/// default implementation, while platform implementations that `implements` this
/// interface will be broken by newly added methods.
abstract class OfflineTranscriptionPlatform extends PlatformInterface {
  /// Constructs a OfflineTranscriptionPlatform.
  OfflineTranscriptionPlatform() : super(token: _token);

  static final Object _token = Object();

  static OfflineTranscriptionPlatform _instance = MethodChannelOfflineTranscription();

  /// The default instance of [OfflineTranscriptionPlatform] to use.
  ///
  /// Defaults to [MethodChannelOfflineTranscription].
  static OfflineTranscriptionPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [OfflineTranscriptionPlatform] when
  /// they register themselves.
  static set instance(OfflineTranscriptionPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Returns the current platform version.
  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  /// Transcribes an audio file at the given path.
  ///
  /// [audioFilePath] is the absolute path to the audio file to transcribe.
  /// [modelPath] is the absolute path to the model directory (Android only).
  ///
  /// Returns the transcribed text as a string.
  Future<String?> transcribeAudioFile(String audioFilePath, {String? modelPath}) {
    throw UnimplementedError('transcribeAudioFile() has not been implemented.');
  }

  /// Transcribes an audio file at the given path and returns metadata.
  ///
  /// [audioFilePath] is the absolute path to the audio file to transcribe.
  /// [modelPath] is the absolute path to the model directory (Android only).
  /// [language] is the language code to use for transcription.
  /// [forceTranscription] forces transcription attempt even on files that appear to be music.
  ///
  /// Returns the transcribed text with metadata as a JSON string.
  Future<String?> transcribeAudioFileWithMetadata(String audioFilePath, {String? modelPath, String? language, bool forceTranscription = false}) {
    throw UnimplementedError('transcribeAudioFileWithMetadata() has not been implemented.');
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
    throw UnimplementedError('checkPermission() has not been implemented.');
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
    throw UnimplementedError('requestPermission() has not been implemented.');
  }

  /// Downloads a model for offline speech recognition (Android only).
  ///
  /// [modelUrl] is the URL to download the model from.
  /// [destinationPath] is the absolute path where the model should be saved.
  /// [language] is the language code for the model.
  ///
  /// Returns true if the download was successful, false otherwise.
  Future<bool?> downloadModel(String modelUrl, String destinationPath, {String? language}) {
    throw UnimplementedError('downloadModel() has not been implemented.');
  }
}
