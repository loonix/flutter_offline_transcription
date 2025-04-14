import Flutter
import UIKit
import Speech
import AVFoundation

public class OfflineTranscriptionPlugin: NSObject, FlutterPlugin {
  private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
  
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "offline_transcription", binaryMessenger: registrar.messenger())
    let instance = OfflineTranscriptionPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getPlatformVersion":
      result("iOS " + UIDevice.current.systemVersion)
    case "transcribeAudioFile":
      guard let args = call.arguments as? [String: Any],
            let audioFilePath = args["audioFilePath"] as? String else {
        result(FlutterError(code: "INVALID_ARGUMENTS", message: "Audio file path must be provided", details: nil))
        return
      }
      
      transcribeAudioFile(audioFilePath: audioFilePath, result: result)
    case "transcribeAudioFileWithMetadata":
      guard let args = call.arguments as? [String: Any],
            let audioFilePath = args["audioFilePath"] as? String else {
        result(FlutterError(code: "INVALID_ARGUMENTS", message: "Audio file path must be provided", details: nil))
        return
      }
      
      // Get the language if specified
      let language = args["language"] as? String
      
      // Get forceTranscription flag to bypass music detection
      let forceTranscription = args["forceTranscription"] as? Bool ?? false
      
      transcribeAudioFileWithMetadata(audioFilePath: audioFilePath, language: language, forceTranscription: forceTranscription, result: result)
    case "checkPermission":
      checkSpeechRecognitionPermission(result: result)
    case "requestPermission":
      requestSpeechRecognitionPermission(result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
  
  private func transcribeAudioFile(audioFilePath: String, result: @escaping FlutterResult) {
    // Check if speech recognition is available
    guard speechRecognizer != nil, speechRecognizer!.isAvailable else {
      result(FlutterError(code: "UNAVAILABLE", message: "Speech recognition is not available on this device", details: nil))
      return
    }
    
    // Check authorization status
    SFSpeechRecognizer.requestAuthorization { status in
      switch status {
      case .authorized:
        self.performTranscription(audioFilePath: audioFilePath, result: result)
      case .denied:
        result(FlutterError(code: "PERMISSION_DENIED", message: "Speech recognition permission denied", details: nil))
      case .restricted:
        result(FlutterError(code: "PERMISSION_RESTRICTED", message: "Speech recognition is restricted on this device", details: nil))
      case .notDetermined:
        result(FlutterError(code: "PERMISSION_NOT_DETERMINED", message: "Speech recognition permission not determined", details: nil))
      @unknown default:
        result(FlutterError(code: "UNKNOWN_ERROR", message: "Unknown permission status", details: nil))
      }
    }
  }
  
  private func transcribeAudioFileWithMetadata(audioFilePath: String, language: String?, forceTranscription: Bool, result: @escaping FlutterResult) {
    // Set the locale based on language parameter if provided
    var recognizer = self.speechRecognizer
    if let lang = language {
      let locale: Locale
      switch lang {
      case "en_us":
        locale = Locale(identifier: "en-US")
      case "en_uk":
        locale = Locale(identifier: "en-GB")
      case "pt_PT":
        locale = Locale(identifier: "pt-PT")
      default:
        locale = Locale(identifier: "en-US")
      }
      recognizer = SFSpeechRecognizer(locale: locale)
    }
    
    // Check if speech recognition is available
    guard recognizer != nil, recognizer!.isAvailable else {
      result(FlutterError(code: "UNAVAILABLE", message: "Speech recognition is not available on this device or language", details: nil))
      return
    }
    
    // Check authorization status
    SFSpeechRecognizer.requestAuthorization { status in
      switch status {
      case .authorized:
        self.performTranscriptionWithMetadata(audioFilePath: audioFilePath, recognizer: recognizer!, forceTranscription: forceTranscription, result: result)
      case .denied:
        result(FlutterError(code: "PERMISSION_DENIED", message: "Speech recognition permission denied", details: nil))
      case .restricted:
        result(FlutterError(code: "PERMISSION_RESTRICTED", message: "Speech recognition is restricted on this device", details: nil))
      case .notDetermined:
        result(FlutterError(code: "PERMISSION_NOT_DETERMINED", message: "Speech recognition permission not determined", details: nil))
      @unknown default:
        result(FlutterError(code: "UNKNOWN_ERROR", message: "Unknown permission status", details: nil))
      }
    }
  }
  
  private func performTranscription(audioFilePath: String, result: @escaping FlutterResult) {
    let fileURL = URL(fileURLWithPath: audioFilePath)
    
    // Create a recognition request
    let request = SFSpeechURLRecognitionRequest(url: fileURL)
    
    // Set request properties
    request.shouldReportPartialResults = false
    
    // Set recognition task options for offline recognition
    if #available(iOS 13, *) {
      request.requiresOnDeviceRecognition = true
    }
    
    // Perform recognition
    speechRecognizer?.recognitionTask(with: request) { (response, error) in
      if let error = error {
        result(FlutterError(code: "TRANSCRIPTION_ERROR", message: error.localizedDescription, details: nil))
        return
      }
      
      guard let response = response else {
        result(FlutterError(code: "NO_RESPONSE", message: "No transcription response received", details: nil))
        return
      }
      
      if response.isFinal {
        result(response.bestTranscription.formattedString)
      }
    }
  }
  
  private func performTranscriptionWithMetadata(audioFilePath: String, recognizer: SFSpeechRecognizer, forceTranscription: Bool, result: @escaping FlutterResult) {
    let originalURL = URL(fileURLWithPath: audioFilePath)
    
    print("Starting transcription of file: \(audioFilePath)")
    print("File exists: \(FileManager.default.fileExists(atPath: audioFilePath))")
    print("Force transcription: \(forceTranscription)")
    
    // Check if this might be a music file (based on filename or path)
    let fileName = originalURL.lastPathComponent.lowercased()
    let isMusicFile = fileName.contains("vocal") || 
                     fileName.contains("music") || 
                     fileName.contains("song") || 
                     fileName.contains("audio") ||
                     fileName.contains("track")
    
    print("File name: \(fileName), detected as music file: \(isMusicFile)")
    
    // First check if we need to convert the audio file
    convertAudioIfNeeded(originalURL) { [weak self] convertedURL, error in
      guard let self = self else { return }
      
      if let error = error {
        print("Failed to prepare audio: \(error.localizedDescription)")
        result(FlutterError(code: "CONVERSION_ERROR", message: "Failed to convert audio: \(error.localizedDescription)", details: nil))
        return
      }
      
      // Use the converted URL if available, otherwise use the original
      let fileURL = convertedURL ?? originalURL
      
      print("Processing audio file at path: \(fileURL.path)")
      
      // If it's likely a music file and we're not forcing transcription, use special handling
      if isMusicFile && !forceTranscription {
        print("Using specialized handling for music file")
        self.processMusicFile(fileURL: fileURL, result: result)
        return
      }
      
      // If music file with force transcription, use the enhanced approach
      if isMusicFile && forceTranscription {
        print("Forced transcription of music file using enhanced approach")
        self.processEnhancedMusicTranscription(fileURL: fileURL, recognizer: recognizer, result: result)
        return
      }
      
      // Regular speech file handling
      self.processRegularSpeechFile(fileURL: fileURL, recognizer: recognizer, result: result)
    }
  }
  
  private func processEnhancedMusicTranscription(fileURL: URL, recognizer: SFSpeechRecognizer, result: @escaping FlutterResult) {
    // This method uses a specialized approach for music content with forced transcription
    let asset = AVAsset(url: fileURL)
    let duration = CMTimeGetSeconds(asset.duration)
    print("Music file duration for enhanced transcription: \(duration) seconds")
    
    // For music/rap transcription, we need to process it differently:
    // 1. Split into very short segments (3-5 seconds)
    // 2. Process each segment with different recognition settings
    // 3. Apply speech enhancement preprocessing
    
    // Create shorter segments (3 seconds with 1 second overlap)
    let segmentDuration: Float64 = 3.0
    let overlap: Float64 = 1.0
    let segments = Int(ceil(duration / (segmentDuration - overlap)))
    
    print("Processing \(segments) short segments for enhanced music transcription")
    
    var allTranscriptions: [String] = []
    var allWords: [[String: Any]] = []
    var currentTimestamp: Float64 = 0.0
    
    let group = DispatchGroup()
    let queue = DispatchQueue(label: "com.example.enhanced.transcription", attributes: .concurrent)
    
    // Process segments in parallel with different recognition settings
    for i in 0..<segments {
      let startTime = Double(i) * (segmentDuration - overlap)
      let endTime = min(startTime + segmentDuration, duration)
      
      print("Processing enhanced segment \(i+1)/\(segments): \(startTime)s to \(endTime)s")
      
      // Skip if segment is too short
      if endTime - startTime < 1.0 {
        print("Segment too short, skipping")
        continue
      }
      
      group.enter()
      queue.async {
        // Try different recognition techniques for this segment
        self.extractAndEnhancedTranscribe(
          asset: asset,
          startTime: startTime,
          endTime: endTime,
          recognizer: recognizer,
          attemptNumber: 1
        ) { (segmentText, recognizedWords) in
          queue.sync {
            if !segmentText.isEmpty {
              print("Enhanced segment \(i+1) transcription: \(segmentText)")
              allTranscriptions.append(segmentText)
              
              // Add word-level data with adjusted timestamps
              for var word in recognizedWords {
                if var timestamp = word["timestamp"] as? Double {
                  timestamp += startTime
                  word["timestamp"] = timestamp
                }
                allWords.append(word)
              }
            } else {
              print("Enhanced segment \(i+1) returned no transcription")
            }
          }
          group.leave()
        }
      }
    }
    
    // Wait for all segments to complete
    group.notify(queue: .main) {
      // Combine all segment transcriptions
      let combinedText = allTranscriptions.joined(separator: " ")
      print("Combined enhanced transcription: \(combinedText)")
      
      // Create response object
      var metadata: [String: Any] = [:]
      
      if combinedText.isEmpty {
        metadata["text"] = "Unable to transcribe this audio content even with forced transcription. The content may be too musical or have unclear vocals."
      } else {
        metadata["text"] = combinedText
      }
      
      // Sort words by timestamp
      let sortedWords = allWords.sorted { 
        ($0["timestamp"] as? Double ?? 0) < ($1["timestamp"] as? Double ?? 0) 
      }
      
      metadata["words"] = sortedWords.isEmpty ? [["word": metadata["text"] ?? "", "confidence": 0.5, "timestamp": 0, "duration": duration]] : sortedWords
      
      do {
        let jsonData = try JSONSerialization.data(withJSONObject: metadata, options: .prettyPrinted)
        if let jsonString = String(data: jsonData, encoding: .utf8) {
          result(jsonString)
        } else {
          result(FlutterError(code: "JSON_ERROR", message: "Failed to convert metadata to JSON string", details: nil))
        }
      } catch {
        result(FlutterError(code: "JSON_ERROR", message: "Failed to serialize metadata: \(error.localizedDescription)", details: nil))
      }
    }
  }
  
  private func extractAndEnhancedTranscribe(
    asset: AVAsset,
    startTime: Double,
    endTime: Double,
    recognizer: SFSpeechRecognizer,
    attemptNumber: Int,
    completion: @escaping (String, [[String: Any]]) -> Void
  ) {
    // Multiple approaches will be tried in sequence if previous ones fail
    
    // Create a temporary file for the segment
    let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
    let outputUrl = URL(fileURLWithPath: documentsPath).appendingPathComponent("enhanced_segment_\(UUID().uuidString).m4a")
    
    // Set up export session with different quality settings
    let presetName = attemptNumber == 1 ? AVAssetExportPresetAppleM4A : AVAssetExportPresetMediumQuality
    guard let exportSession = AVAssetExportSession(asset: asset, presetName: presetName) else {
      print("Failed to create export session for attempt \(attemptNumber)")
      if attemptNumber < 3 {
        extractAndEnhancedTranscribe(asset: asset, startTime: startTime, endTime: endTime, 
                                    recognizer: recognizer, attemptNumber: attemptNumber + 1, completion: completion)
      } else {
        completion("", [])
      }
      return
    }
    
    exportSession.outputURL = outputUrl
    
    // Check available file types
    let supportedFileTypes = exportSession.supportedFileTypes
    if supportedFileTypes.contains(.m4a) {
      exportSession.outputFileType = .m4a
    } else if !supportedFileTypes.isEmpty {
      exportSession.outputFileType = supportedFileTypes[0]
    } else {
      print("No supported file types available for attempt \(attemptNumber)")
      if attemptNumber < 3 {
        extractAndEnhancedTranscribe(asset: asset, startTime: startTime, endTime: endTime, 
                                    recognizer: recognizer, attemptNumber: attemptNumber + 1, completion: completion)
      } else {
        completion("", [])
      }
      return
    }
    
    // Set time range for the segment
    let startCMTime = CMTimeMakeWithSeconds(Float64(startTime), preferredTimescale: 48000)
    let endCMTime = CMTimeMakeWithSeconds(Float64(endTime), preferredTimescale: 48000)
    let timeRange = CMTimeRangeMake(start: startCMTime, duration: CMTimeSubtract(endCMTime, startCMTime))
    exportSession.timeRange = timeRange
    
    print("Exporting enhanced segment with attempt \(attemptNumber)")
    
    exportSession.exportAsynchronously {
      switch exportSession.status {
      case .completed:
        print("Enhanced segment export completed for attempt \(attemptNumber)")
        
        // Configure recognition based on attempt number
        let request = SFSpeechURLRecognitionRequest(url: outputUrl)
        request.shouldReportPartialResults = false
        
        // Attempt-specific optimizations
        if #available(iOS 13, *) {
          if attemptNumber == 1 {
            // First attempt: Use dictation hint
            request.requiresOnDeviceRecognition = true
            request.taskHint = .dictation
            
          } else if attemptNumber == 2 {
            // Second attempt: Use confirmation hint
            request.requiresOnDeviceRecognition = false  // Try server recognition if available
            request.taskHint = .confirmation
            
          } else {
            // Third attempt: Use search hint
            request.taskHint = .search
          }
        }
        
        // Use a semaphore for synchronization
        let semaphore = DispatchSemaphore(value: 0)
        var segmentText = ""
        var wordInfo: [[String: Any]] = []
        
        recognizer.recognitionTask(with: request) { (result, error) in
          defer {
            if result?.isFinal == true || error != nil {
              // Clean up the temporary segment file
              try? FileManager.default.removeItem(at: outputUrl)
              semaphore.signal()
            }
          }
          
          if let error = error {
            print("Enhanced segment transcription error: \(error.localizedDescription)")
            return
          }
          
          if let result = result, result.isFinal {
            segmentText = result.bestTranscription.formattedString
            
            // Extract word-level information
            for segment in result.bestTranscription.segments {
              let word: [String: Any] = [
                "word": segment.substring,
                "confidence": segment.confidence,
                "duration": segment.duration,
                "timestamp": segment.timestamp
              ]
              wordInfo.append(word)
            }
          }
        }
        
        // Wait with timeout
        let timeoutResult = semaphore.wait(timeout: .now() + 30)
        
        if timeoutResult == .timedOut {
          print("Enhanced transcription timed out for attempt \(attemptNumber)")
        }
        
        if segmentText.isEmpty && attemptNumber < 3 {
          // Try next method if this one failed
          self.extractAndEnhancedTranscribe(asset: asset, startTime: startTime, endTime: endTime,
                                          recognizer: recognizer, attemptNumber: attemptNumber + 1, completion: completion)
        } else {
          completion(segmentText, wordInfo)
        }
        
      case .failed:
        print("Enhanced segment export failed: \(exportSession.error?.localizedDescription ?? "unknown error")")
        try? FileManager.default.removeItem(at: outputUrl)
        
        if attemptNumber < 3 {
          self.extractAndEnhancedTranscribe(asset: asset, startTime: startTime, endTime: endTime,
                                          recognizer: recognizer, attemptNumber: attemptNumber + 1, completion: completion)
        } else {
          completion("", [])
        }
        
      default:
        print("Unexpected enhanced segment export status: \(exportSession.status.rawValue)")
        try? FileManager.default.removeItem(at: outputUrl)
        
        if attemptNumber < 3 {
          self.extractAndEnhancedTranscribe(asset: asset, startTime: startTime, endTime: endTime,
                                          recognizer: recognizer, attemptNumber: attemptNumber + 1, completion: completion)
        } else {
          completion("", [])
        }
      }
    }
  }
  
  private func processMusicFile(fileURL: URL, result: @escaping FlutterResult) {
    // For music files, we'll extract small segments and try to transcribe them separately
    // This often works better for music content
    
    let asset = AVAsset(url: fileURL)
    let duration = CMTimeGetSeconds(asset.duration)
    print("Music file duration: \(duration) seconds")
    
    // First check if this is truly music content by analyzing audio features
    analyzeAudioFeatures(asset: asset) { isMusicContent, dominantFeatures in
      print("Audio analysis results - Is music content: \(isMusicContent), Features: \(dominantFeatures)")
      
      // If it's definitely music content, provide a direct feedback about limitations
      if isMusicContent {
        let metadata: [String: Any] = [
          "text": "This appears to be music with vocals. Apple's Speech Recognition is optimized for spoken language and may not effectively transcribe singing or music content.",
          "words": [
            [
              "word": "Music content detected",
              "confidence": 0.9,
              "duration": duration,
              "timestamp": 0.0
            ]
          ],
          "isMusicContent": true,
          "audioFeatures": dominantFeatures
        ]
        
        do {
          let jsonData = try JSONSerialization.data(withJSONObject: metadata, options: .prettyPrinted)
          if let jsonString = String(data: jsonData, encoding: .utf8) {
            result(jsonString)
          } else {
            result(FlutterError(code: "JSON_ERROR", message: "Failed to convert metadata to JSON string", details: nil))
          }
        } catch {
          result(FlutterError(code: "JSON_ERROR", message: "Failed to serialize metadata: \(error.localizedDescription)", details: nil))
        }
        return
      }
      
      // Continue with segmented transcription approach for non-clear music content
      // Create 20-second segments with 5-second overlap
      let segmentDuration: Float64 = 20.0
      let overlap: Float64 = 5.0
      let segments = Int(ceil(duration / (segmentDuration - overlap)))
      
      print("Processing \(segments) segments")
      
      var allTranscriptions: [String] = []
      let group = DispatchGroup()
      let queue = DispatchQueue(label: "com.example.transcription.segments", attributes: .concurrent)
      
      // Setup local recognizer
      let localRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))!
      
      // Process each segment
      for i in 0..<segments {
        let startTime = Double(i) * (segmentDuration - overlap)
        let endTime = min(startTime + segmentDuration, duration)
        
        print("Processing segment \(i+1)/\(segments): \(startTime)s to \(endTime)s")
        
        // Skip if segment is too short
        if endTime - startTime < 3.0 {
          print("Segment too short, skipping")
          continue
        }
        
        group.enter()
        queue.async {
          self.extractAndTranscribeSegment(
            asset: asset,
            startTime: startTime,
            endTime: endTime,
            recognizer: localRecognizer
          ) { segmentText in
            if !segmentText.isEmpty {
              print("Segment \(i+1) transcription: \(segmentText)")
              queue.sync {
                allTranscriptions.append(segmentText)
              }
            } else {
              print("Segment \(i+1) returned no transcription")
            }
            group.leave()
          }
        }
      }
      
      // Wait for all segments to complete
      group.notify(queue: .main) {
        // Combine all segment transcriptions
        let combinedText = allTranscriptions.joined(separator: " ")
        print("Combined transcription: \(combinedText)")
        
        // Create response object
        var metadata: [String: Any] = [:]
        
        if combinedText.isEmpty {
          metadata["text"] = "Unable to transcribe this audio content. It may contain music or non-speech audio that cannot be recognized by the system."
        } else {
          metadata["text"] = combinedText
        }
        
        // Create a simple word-level metadata for compatibility
        var words: [[String: Any]] = []
        if let textValue = metadata["text"] as? String, !textValue.isEmpty {
          words.append([
            "word": textValue,
            "confidence": 0.8,
            "duration": duration,
            "timestamp": 0.0
          ])
        }
        metadata["words"] = words
        
        do {
          let jsonData = try JSONSerialization.data(withJSONObject: metadata, options: .prettyPrinted)
          if let jsonString = String(data: jsonData, encoding: .utf8) {
            result(jsonString)
          } else {
            result(FlutterError(code: "JSON_ERROR", message: "Failed to convert metadata to JSON string", details: nil))
          }
        } catch {
          result(FlutterError(code: "JSON_ERROR", message: "Failed to serialize metadata: \(error.localizedDescription)", details: nil))
        }
      }
    }
  }
  
  // Analyze audio to determine if it's likely music content
  private func analyzeAudioFeatures(asset: AVAsset, completion: @escaping (Bool, [String: Any]) -> Void) {
    // We'll check audio features like:
    // - Consistent beat pattern (music)
    // - Frequency distribution
    // - Presence of instruments
    
    // Use AVAssetReader to read audio samples
    var audioTrack: AVAssetTrack?
    
    if let firstAudioTrack = asset.tracks(withMediaType: .audio).first {
      audioTrack = firstAudioTrack
    }
    
    guard let audioTrack = audioTrack else {
      completion(false, ["error": "No audio track found"])
      return
    }
    
    // Simple heuristics based on filename and metadata
    // Extract filename from the asset. AVAsset doesn't have direct url property
    var filename = ""
    if let urlAsset = asset as? AVURLAsset {
      filename = urlAsset.url.lastPathComponent.lowercased()
    }
    
    var musicIndicators = 0
    var dominantFeatures: [String: Any] = [:]
    
    // Check filename for music indicators
    let musicRelatedKeywords = ["song", "music", "vocal", "track", "beat", "instrumental", "remix", "album"]
    for keyword in musicRelatedKeywords {
      if filename.contains(keyword) {
        musicIndicators += 1
        dominantFeatures["filename_match"] = keyword
      }
    }
    
    // Check audio format features
    let formatDescription = audioTrack.formatDescriptions[0] as! CMAudioFormatDescription
    if let streamBasicDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription) {
      let sampleRate = streamBasicDescription.pointee.mSampleRate
      let channels = streamBasicDescription.pointee.mChannelsPerFrame
      
      // Music typically uses stereo (2 channels) and high sample rates
      if channels == 2 {
        musicIndicators += 1
        dominantFeatures["stereo"] = true
      }
      
      if sampleRate >= 44100 {
        musicIndicators += 1
        dominantFeatures["high_quality"] = true
        dominantFeatures["sample_rate"] = sampleRate
      }
    }
    
    // Check duration - music tracks are typically 2-5 minutes
    let duration = CMTimeGetSeconds(asset.duration)
    if duration > 60 && duration < 360 {
      musicIndicators += 1
      dominantFeatures["music_length_duration"] = duration
    }
    
    // Determine if this is likely music content
    let isMusicContent = musicIndicators >= 3
    
    // Additional metadata from the asset if available
    if let metadata = asset.metadata as? [AVMetadataItem] {
      for item in metadata {
        if let key = item.commonKey?.rawValue, let value = item.value {
          dominantFeatures[key] = String(describing: value)
          
          // Check for music-related metadata
          if key.contains("artist") || key.contains("album") || key.contains("genre") {
            musicIndicators += 1
            dominantFeatures["has_music_metadata"] = true
          }
        }
      }
    }
    
    completion(isMusicContent, dominantFeatures)
  }
  
  private func extractAndTranscribeSegment(
    asset: AVAsset,
    startTime: Double,
    endTime: Double,
    recognizer: SFSpeechRecognizer,
    completion: @escaping (String) -> Void
  ) {
    // Create a temporary file for the segment
    let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
    let outputUrl = URL(fileURLWithPath: documentsPath).appendingPathComponent("segment_\(UUID().uuidString).m4a")
    
    // Set up export session for the segment
    guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
      print("Failed to create export session")
      completion("")
      return
    }
    
    exportSession.outputURL = outputUrl
    
    // Check available file types and use a supported one
    let supportedFileTypes = exportSession.supportedFileTypes
    print("Supported file types: \(supportedFileTypes)")
    
    if supportedFileTypes.contains(.m4a) {
      exportSession.outputFileType = .m4a
    } else if supportedFileTypes.contains(.mp4) {
      exportSession.outputFileType = .mp4
    } else if !supportedFileTypes.isEmpty {
      exportSession.outputFileType = supportedFileTypes[0]
    } else {
      print("No supported file types available")
      completion("")
      return
    }
    
    // Set time range for the segment
    let startCMTime = CMTimeMakeWithSeconds(Float64(startTime), preferredTimescale: 600)
    let endCMTime = CMTimeMakeWithSeconds(Float64(endTime), preferredTimescale: 600)
    let timeRange = CMTimeRangeMake(start: startCMTime, duration: CMTimeSubtract(endCMTime, startCMTime))
    exportSession.timeRange = timeRange
    
    if let outputFileType = exportSession.outputFileType {
      print("Exporting segment with file type: \(outputFileType.rawValue)")
    } else {
      print("Exporting segment with no file type specified")
    }
    
    exportSession.exportAsynchronously {
      switch exportSession.status {
      case .completed:
        print("Segment export completed")
        
        // Now transcribe the segment
        let request = SFSpeechURLRecognitionRequest(url: outputUrl)
        request.shouldReportPartialResults = false
        if #available(iOS 13, *) {
          request.requiresOnDeviceRecognition = true
        }
        
        // Use a semaphore to make this synchronous
        let semaphore = DispatchSemaphore(value: 0)
        var segmentText = ""
        
        recognizer.recognitionTask(with: request) { (result, error) in
          defer {
            if result?.isFinal == true || error != nil {
              // Clean up the temporary segment file
              try? FileManager.default.removeItem(at: outputUrl)
              semaphore.signal()
            }
          }
          
          if let error = error {
            print("Segment transcription error: \(error.localizedDescription)")
            return
          }
          
          if let result = result, result.isFinal {
            segmentText = result.bestTranscription.formattedString
          }
        }
        
        // Wait for completion with a timeout
        _ = semaphore.wait(timeout: .now() + 60)
        completion(segmentText)
        
      case .failed:
        print("Segment export failed: \(exportSession.error?.localizedDescription ?? "unknown error")")
        try? FileManager.default.removeItem(at: outputUrl)
        completion("")
        
      default:
        print("Unexpected segment export status: \(exportSession.status.rawValue)")
        try? FileManager.default.removeItem(at: outputUrl)
        completion("")
      }
    }
  }
  
  private func processRegularSpeechFile(fileURL: URL, recognizer: SFSpeechRecognizer, result: @escaping FlutterResult) {
    // Create a recognition request
    let request = SFSpeechURLRecognitionRequest(url: fileURL)
    
    // Configure the request for better results
    request.shouldReportPartialResults = false
    request.taskHint = .dictation  // Better for continuous speech recognition
    
    // Set recognition task options for offline recognition
    if #available(iOS 13, *) {
      request.requiresOnDeviceRecognition = true
    }
    
    // Increase timeout for longer files
    let taskTimeout: TimeInterval = 300.0 // 5 minutes
    
    // Create a semaphore to handle timeout
    let semaphore = DispatchSemaphore(value: 0)
    var transcriptionResult: SFSpeechRecognitionResult?
    var transcriptionError: Error?
    var isFinished = false
    
    print("Starting recognition task for file: \(fileURL.path)")
    
    // Perform recognition
    let task = recognizer.recognitionTask(with: request) { (response, error) in
      // If we created a temporary converted file, clean it up later
      defer {
        if !isFinished && (response?.isFinal == true || error != nil) {
          isFinished = true
          semaphore.signal()
        }
      }
      
      if let error = error {
        print("Transcription error: \(error.localizedDescription)")
        transcriptionError = error
        return
      }
      
      guard let response = response else {
        print("No transcription response received")
        transcriptionError = NSError(domain: "SpeechRecognition", code: 1000, userInfo: [NSLocalizedDescriptionKey: "No transcription response received"])
        return
      }
      
      if response.isFinal {
        print("Final transcription received")
        transcriptionResult = response
      }
    }
    
    // Set up a timeout handler
    DispatchQueue.global().asyncAfter(deadline: .now() + taskTimeout) {
      if !isFinished {
        print("Transcription timed out after \(taskTimeout) seconds")
        task.cancel()
        transcriptionError = NSError(domain: "SpeechRecognition", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Transcription timed out"])
        semaphore.signal()
      }
    }
    
    // Wait for the transcription to complete or timeout
    DispatchQueue.global().async {
      semaphore.wait()
      
      // Return results on the main thread
      DispatchQueue.main.async {
        if let error = transcriptionError {
          print("Returning error: \(error.localizedDescription)")
          result(FlutterError(code: "TRANSCRIPTION_ERROR", message: error.localizedDescription, details: nil))
          return
        }
        
        guard let transcriptionResult = transcriptionResult else {
          print("No transcription result to return")
          result(FlutterError(code: "NO_RESPONSE", message: "No transcription response received", details: nil))
          return
        }
        
        // Create a metadata-rich response
        var metadata: [String: Any] = [:]
        
        // Get the full transcription text
        let text = transcriptionResult.bestTranscription.formattedString
        metadata["text"] = text
        
        // Log the transcription for debugging
        print("Transcription result: \(text)")
        
        // Get word-level information
        var words: [[String: Any]] = []
        let segments = transcriptionResult.bestTranscription.segments
        
        for segment in segments {
          let word: [String: Any] = [
            "word": segment.substring,
            "confidence": segment.confidence,
            "duration": segment.duration,
            "timestamp": segment.timestamp
          ]
          words.append(word)
          print("Word: \(segment.substring), confidence: \(segment.confidence), timestamp: \(segment.timestamp)")
        }
        
        // If we have no words but do have text, create a single word entry
        if let textValue = metadata["text"] as? String, !textValue.isEmpty {
          words.append([
            "word": textValue,
            "confidence": 1.0,
            "duration": 0.0,
            "timestamp": 0.0
          ])
        }
        
        metadata["words"] = words
        
        do {
          // Convert to JSON string
          let jsonData = try JSONSerialization.data(withJSONObject: metadata, options: .prettyPrinted)
          if let jsonString = String(data: jsonData, encoding: .utf8) {
            result(jsonString)
          } else {
            result(FlutterError(code: "JSON_ERROR", message: "Failed to convert metadata to JSON string", details: nil))
          }
        } catch {
          result(FlutterError(code: "JSON_ERROR", message: "Failed to serialize metadata: \(error.localizedDescription)", details: nil))
        }
      }
    }
  }
  
  private func convertAudioIfNeeded(_ url: URL, completion: @escaping (URL?, Error?) -> Void) {
    // Check file type and size
    do {
      let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
      let fileSize = attributes[.size] as! UInt64
      print("Audio file size: \(fileSize) bytes")
      
      if fileSize == 0 {
        completion(nil, NSError(domain: "OfflineTranscriptionError", code: 400, userInfo: [NSLocalizedDescriptionKey: "Audio file is empty"]))
        return
      }
      
      // Get more information about the audio file
      let asset = AVAsset(url: url)
      let audioTracks = asset.tracks(withMediaType: .audio)
      
      print("File at path: \(url.path)")
      print("File exists: \(FileManager.default.fileExists(atPath: url.path))")
      print("Audio tracks count: \(audioTracks.count)")
      
      if audioTracks.count == 0 {
        completion(nil, NSError(domain: "OfflineTranscriptionError", code: 400, userInfo: [NSLocalizedDescriptionKey: "No audio tracks found in the file"]))
        return
      }
      
      // Get audio format details
      let audioTrack = audioTracks[0]
      let formatDesc = audioTrack.formatDescriptions[0] as! CMAudioFormatDescription
      let basicDesc = CMAudioFormatDescriptionGetStreamBasicDescription(formatDesc)
      
      if let basicDesc = basicDesc {
        print("Sample rate: \(basicDesc.pointee.mSampleRate)")
        print("Channels: \(basicDesc.pointee.mChannelsPerFrame)")
        print("Format ID: \(basicDesc.pointee.mFormatID)")
      }
      
      // Check file extension and MIME type
      let fileExtension = url.pathExtension.lowercased()
      print("File extension: \(fileExtension)")
      
      // Try to create a sample buffer reader for the audio file
      var assetReader: AVAssetReader?
      do {
        assetReader = try AVAssetReader(asset: asset)
      } catch {
        print("Error creating asset reader: \(error.localizedDescription)")
      }
      
      // If the file is already in a compatible format and can be read, use it directly
      if ["wav", "m4a", "mp3", "caf", "aac", "mp4", "aiff"].contains(fileExtension) && assetReader != nil {
        // Additional check: try creating a Speech Recognition request to test compatibility
        let request = SFSpeechURLRecognitionRequest(url: url)
        if SFSpeechRecognizer.authorizationStatus() == .authorized {
          print("File appears to be compatible with Speech Recognition, using directly")
          completion(url, nil)
          return
        } else {
          print("Can't verify Speech Recognition compatibility due to authorization, attempting conversion")
        }
      }
      
      // Otherwise, convert to CAF format
      convertToM4A(url: url, completion: completion)
    } catch {
      print("Error checking file: \(error.localizedDescription)")
      completion(nil, error)
    }
  }
  
  private func convertToM4A(url: URL, completion: @escaping (URL?, Error?) -> Void) {
    do {
      // Create temporary file for the converted audio
      let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
      let outputUrl = URL(fileURLWithPath: documentsPath).appendingPathComponent("temp_converted_audio_\(UUID().uuidString).m4a")
      
      print("Converting audio to M4A format at: \(outputUrl.path)")
      
      // Set up AVAsset from the source URL
      let asset = AVAsset(url: url)
      
      // Check if the asset can be read
      if asset.tracks.isEmpty {
        print("Asset has no tracks, checking if we can create an audio file from the URL directly")
        
        // Try a different approach if the AVAsset doesn't work
        if let audioFile = try? AVAudioFile(forReading: url) {
          print("Successfully created AVAudioFile, attempting direct conversion")
          
          let format = AVAudioFormat(standardFormatWithSampleRate: audioFile.processingFormat.sampleRate, channels: audioFile.processingFormat.channelCount)
          let buffer = AVAudioPCMBuffer(pcmFormat: audioFile.processingFormat, frameCapacity: AVAudioFrameCount(audioFile.length))
          
          try audioFile.read(into: buffer!)
          
          // Create a new audio file with the converted format
          let outputFile = try AVAudioFile(forWriting: outputUrl, settings: format!.settings)
          try outputFile.write(from: buffer!)
          
          completion(outputUrl, nil)
          return
        }
        
        completion(nil, NSError(domain: "OfflineTranscriptionError", code: 400, userInfo: [NSLocalizedDescriptionKey: "Audio file format not supported or file is corrupted"]))
        return
      }
      
      // Create an export session
      guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
        completion(nil, NSError(domain: "OfflineTranscriptionError", code: 500, userInfo: [NSLocalizedDescriptionKey: "Could not create export session"]))
        return
      }
      
      exportSession.outputURL = outputUrl
      exportSession.outputFileType = .m4a
      exportSession.shouldOptimizeForNetworkUse = true
      
      // Export the file
      exportSession.exportAsynchronously {
        print("Export completed with status: \(exportSession.status.rawValue)")
        
        switch exportSession.status {
        case .completed:
          print("Export completed successfully")
          completion(outputUrl, nil)
        case .failed:
          print("Export failed with error: \(exportSession.error?.localizedDescription ?? "unknown error")")
          completion(nil, exportSession.error ?? NSError(domain: "OfflineTranscriptionError", code: 500, userInfo: [NSLocalizedDescriptionKey: "Export failed with unknown error"]))
        case .cancelled:
          completion(nil, NSError(domain: "OfflineTranscriptionError", code: 500, userInfo: [NSLocalizedDescriptionKey: "Export cancelled"]))
        default:
          completion(nil, NSError(domain: "OfflineTranscriptionError", code: 500, userInfo: [NSLocalizedDescriptionKey: "Unknown export status: \(exportSession.status.rawValue)"]))
        }
      }
    } catch {
      print("Error during conversion: \(error.localizedDescription)")
      completion(nil, error)
    }
  }
  
  private func checkSpeechRecognitionPermission(result: @escaping FlutterResult) {
    let status = SFSpeechRecognizer.authorizationStatus()
    switch status {
    case .authorized:
      result("authorized")
    case .denied:
      result("denied")
    case .restricted:
      result("restricted")
    case .notDetermined:
      result("notDetermined")
    @unknown default:
      result("unknown")
    }
  }
  
  private func requestSpeechRecognitionPermission(result: @escaping FlutterResult) {
    SFSpeechRecognizer.requestAuthorization { status in
      switch status {
      case .authorized:
        result("authorized")
      case .denied:
        result("denied")
      case .restricted:
        result("restricted")
      case .notDetermined:
        result("notDetermined")
      @unknown default:
        result("unknown")
      }
    }
  }
}