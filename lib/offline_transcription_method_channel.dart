import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'offline_transcription_platform_interface.dart';

/// An implementation of [OfflineTranscriptionPlatform] that uses method channels.
class MethodChannelOfflineTranscription extends OfflineTranscriptionPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('offline_transcription');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }

  @override
  Future<String?> transcribeAudioFile(String audioFilePath, {String? modelPath}) async {
    final Map<String, dynamic> args = {
      'audioFilePath': audioFilePath,
    };

    if (modelPath != null) {
      args['modelPath'] = modelPath;
    }

    final String? result = await methodChannel.invokeMethod<String>('transcribeAudioFile', args);
    return result;
  }

  @override
  Future<String?> transcribeAudioFileWithMetadata(String audioFilePath, {String? modelPath, String? language, bool forceTranscription = false}) async {
    final Map<String, dynamic> args = {
      'audioFilePath': audioFilePath,
      'forceTranscription': forceTranscription,
    };

    if (modelPath != null) {
      args['modelPath'] = modelPath;
    }

    if (language != null) {
      args['language'] = language;
    }

    final String? result = await methodChannel.invokeMethod<String>('transcribeAudioFileWithMetadata', args);
    return result;
  }

  @override
  Future<String?> checkPermission() async {
    final String? status = await methodChannel.invokeMethod<String>('checkPermission');
    return status;
  }

  @override
  Future<String?> requestPermission() async {
    final String? status = await methodChannel.invokeMethod<String>('requestPermission');
    return status;
  }

  @override
  Future<bool?> downloadModel(String modelUrl, String destinationPath, {String? language}) async {
    final Map<String, dynamic> args = {
      'modelUrl': modelUrl,
      'destinationPath': destinationPath,
    };

    if (language != null) {
      args['language'] = language;
    }

    final bool? result = await methodChannel.invokeMethod<bool>('downloadModel', args);
    return result;
  }
}
