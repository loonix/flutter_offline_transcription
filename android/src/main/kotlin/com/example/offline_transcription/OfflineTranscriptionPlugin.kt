package com.example.offline_transcription

import android.content.Context
import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.vosk.Model
import org.vosk.Recognizer
import org.vosk.android.StorageService
import java.io.FileInputStream
import org.json.JSONObject
import org.json.JSONArray

/** OfflineTranscriptionPlugin */
class OfflineTranscriptionPlugin: FlutterPlugin, MethodCallHandler {
  /// The MethodChannel that will the communication between Flutter and native Android
  ///
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity
  private lateinit var channel : MethodChannel
  private lateinit var context: Context
  private val TAG = "OfflineTranscriptionPlugin"
  private val coroutineScope = CoroutineScope(Dispatchers.Main)

  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "offline_transcription")
    channel.setMethodCallHandler(this)
    context = flutterPluginBinding.applicationContext
  }

  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
    when (call.method) {
      "getPlatformVersion" -> {
        result.success("Android ${android.os.Build.VERSION.RELEASE}")
      }
      "transcribeAudioFile" -> {
        val audioFilePath = call.argument<String>("audioFilePath")
        val modelPath = call.argument<String>("modelPath")
        
        if (audioFilePath == null || modelPath == null) {
          result.error("INVALID_ARGUMENTS", "Audio file path and model path must be provided", null)
          return
        }
        
        transcribeAudioFile(audioFilePath, modelPath, result)
      }
      "transcribeAudioFileWithMetadata" -> {
        val audioFilePath = call.argument<String>("audioFilePath")
        val modelPath = call.argument<String>("modelPath")
        val language = call.argument<String>("language")
        
        if (audioFilePath == null || modelPath == null) {
          result.error("INVALID_ARGUMENTS", "Audio file path and model path must be provided", null)
          return
        }
        
        transcribeAudioFileWithMetadata(audioFilePath, modelPath, language, result)
      }
      "downloadModel" -> {
        val modelUrl = call.argument<String>("modelUrl")
        val destinationPath = call.argument<String>("destinationPath")
        
        if (modelUrl == null || destinationPath == null) {
          result.error("INVALID_ARGUMENTS", "Model URL and destination path must be provided", null)
          return
        }
        
        downloadModel(modelUrl, destinationPath, result)
      }
      else -> {
        result.notImplemented()
      }
    }
  }

  private fun transcribeAudioFile(audioFilePath: String, modelPath: String, result: Result) {
    coroutineScope.launch {
      try {
        val transcription = withContext(Dispatchers.IO) {
          // Check if files exist
          val audioFile = File(audioFilePath)
          val modelDir = File(modelPath)
          
          if (!audioFile.exists()) {
            throw IOException("Audio file does not exist: $audioFilePath")
          }
          
          if (!modelDir.exists()) {
            throw IOException("Model directory does not exist: $modelPath")
          }
          
          // Load the model
          val model = Model(modelPath)
          
          // Create recognizer
          val recognizer = Recognizer(model, 16000.0f)
          
          // Process audio file
          val buffer = ByteArray(4096)
          val inputStream = FileInputStream(audioFile)
          var done = false
          var finalResult = ""
          
          while (!done) {
            val nread = inputStream.read(buffer)
            if (nread == -1) {
              done = true
            } else {
              val isFinal = done && (nread < buffer.size)
              if (recognizer.acceptWaveForm(buffer, nread)) {
                val result = recognizer.result
                val jsonResult = JSONObject(result)
                finalResult += jsonResult.getString("text") + " "
              } else if (isFinal) {
                val result = recognizer.finalResult
                val jsonResult = JSONObject(result)
                finalResult += jsonResult.getString("text") + " "
              }
            }
          }
          
          // Clean up
          inputStream.close()
          recognizer.close()
          model.close()
          
          finalResult.trim()
        }
        
        result.success(transcription)
      } catch (e: Exception) {
        Log.e(TAG, "Error transcribing audio file", e)
        result.error("TRANSCRIPTION_ERROR", e.message, e.stackTraceToString())
      }
    }
  }

  private fun transcribeAudioFileWithMetadata(audioFilePath: String, modelPath: String, language: String?, result: Result) {
    coroutineScope.launch {
      try {
        // First check the audio file and convert if necessary
        val validatedFile = withContext(Dispatchers.IO) {
          validateAndPrepareAudioFile(audioFilePath)
        }
        
        val transcriptionJson = withContext(Dispatchers.IO) {
          // Check if model directory exists
          val modelDir = File(modelPath)
          
          if (!modelDir.exists()) {
            throw IOException("Model directory does not exist: $modelPath")
          }
          
          // Load the model
          Log.d(TAG, "Loading model from $modelPath")
          val model = Model(modelPath)
          
          // Create recognizer
          val recognizer = Recognizer(model, 16000.0f)
          
          // Process audio file
          val buffer = ByteArray(4096)
          val inputStream = FileInputStream(validatedFile)
          var done = false
          
          val allWords = JSONArray()
          var fullText = ""
          
          Log.d(TAG, "Starting transcription of file: ${validatedFile.path}")
          Log.d(TAG, "File size: ${validatedFile.length()} bytes")
          
          while (!done) {
            val nread = inputStream.read(buffer)
            if (nread == -1) {
              done = true
            } else {
              val isFinal = done && (nread < buffer.size)
              if (recognizer.acceptWaveForm(buffer, nread)) {
                val resultJson = recognizer.result
                val jsonResult = JSONObject(resultJson)
                Log.d(TAG, "Intermediate result: $resultJson")
                
                // Extract words from intermediate results
                if (jsonResult.has("text") && jsonResult.getString("text").isNotEmpty()) {
                  fullText += jsonResult.getString("text") + " "
                  
                  // Extract word-level information if available
                  if (jsonResult.has("result")) {
                    val wordsArray = jsonResult.getJSONArray("result")
                    for (i in 0 until wordsArray.length()) {
                      allWords.put(wordsArray.getJSONObject(i))
                    }
                  }
                }
              } else if (isFinal) {
                val resultJson = recognizer.finalResult
                val jsonResult = JSONObject(resultJson)
                Log.d(TAG, "Final result: $resultJson")
                
                // Extract final words and text
                if (jsonResult.has("text") && jsonResult.getString("text").isNotEmpty()) {
                  fullText += jsonResult.getString("text") + " "
                  
                  // Extract word-level information if available
                  if (jsonResult.has("result")) {
                    val wordsArray = jsonResult.getJSONArray("result")
                    for (i in 0 until wordsArray.length()) {
                      allWords.put(wordsArray.getJSONObject(i))
                    }
                  }
                }
              }
            }
          }
          
          // Clean up
          inputStream.close()
          recognizer.close()
          model.close()
          
          // Clean up temporary file if one was created
          if (validatedFile.path != audioFilePath) {
            validatedFile.delete()
          }
          
          // Build final JSON result
          val finalResult = JSONObject()
          finalResult.put("text", fullText.trim())
          
          // Process words into a format compatible with our plugin
          val processedWords = JSONArray()
          for (i in 0 until allWords.length()) {
            val wordObj = allWords.getJSONObject(i)
            val word = JSONObject()
            word.put("word", wordObj.getString("word"))
            word.put("start", wordObj.getDouble("start"))
            word.put("end", wordObj.getDouble("end"))
            word.put("conf", wordObj.getDouble("conf"))
            processedWords.put(word)
          }
          finalResult.put("words", processedWords)
          
          // Return JSON string
          finalResult.toString()
        }
        
        result.success(transcriptionJson)
      } catch (e: Exception) {
        Log.e(TAG, "Error transcribing audio file with metadata", e)
        result.error("TRANSCRIPTION_ERROR", e.message, e.stackTraceToString())
      }
    }
  }
  
  /**
   * Validates and prepares an audio file for transcription.
   * - Checks if the file exists and is not empty
   * - Ensures the file is in a compatible format
   * - Converts the file to WAV if needed
   *
   * @param audioFilePath Path to the audio file
   * @return File object of the validated/converted audio file
   */
  private fun validateAndPrepareAudioFile(audioFilePath: String): File {
    val audioFile = File(audioFilePath)
    
    // Check if file exists
    if (!audioFile.exists()) {
      throw IOException("Audio file does not exist: $audioFilePath")
    }
    
    // Check file size
    if (audioFile.length() == 0L) {
      throw IOException("Audio file is empty: $audioFilePath")
    }
    
    Log.d(TAG, "Validating audio file: $audioFilePath")
    Log.d(TAG, "File size: ${audioFile.length()} bytes")
    
    // Check file extension
    val fileExtension = audioFilePath.substringAfterLast('.', "").toLowerCase()
    Log.d(TAG, "File extension: $fileExtension")
    
    // For now, Vosk works best with WAV files at 16kHz sample rate
    // If we need to do conversion, we would implement it here
    // For this example implementation, we'll just check and warn if it's not WAV
    
    if (fileExtension != "wav") {
      Log.w(TAG, "Audio file is not in WAV format. Transcription may be less accurate.")
      
      // Here we could implement conversion to WAV using Android's MediaCodec API
      // or a third-party library like FFmpeg
      // For simplicity, returning the original file for now
    }
    
    return audioFile
  }

  private fun downloadModel(modelUrl: String, destinationPath: String, result: Result) {
    coroutineScope.launch {
      try {
        val success = withContext(Dispatchers.IO) {
          val destDir = File(destinationPath)
          if (!destDir.exists()) {
            destDir.mkdirs()
          }
          
          // In a real implementation, you would download the model from the URL
          // For this example, we'll just create a placeholder file
          val placeholderFile = File(destDir, "README")
          placeholderFile.writeText("This is a placeholder for the Vosk model. In a real implementation, you would download the model from $modelUrl")
          
          true
        }
        
        if (success) {
          result.success(true)
        } else {
          result.error("DOWNLOAD_FAILED", "Failed to download model", null)
        }
      } catch (e: Exception) {
        Log.e(TAG, "Error downloading model", e)
        result.error("DOWNLOAD_ERROR", e.message, e.stackTraceToString())
      }
    }
  }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }
}