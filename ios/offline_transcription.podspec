#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint offline_transcription.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'offline_transcription'
  s.version          = '0.0.1'
  s.summary          = 'Flutter plugin for offline audio transcription.'
  s.description      = <<-DESC
A Flutter plugin that provides offline audio transcription capabilities using platform-specific implementations.
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'  # Increased for better Speech framework support

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
  
  # Add frameworks
  s.frameworks = 'Speech', 'AVFoundation'
end
