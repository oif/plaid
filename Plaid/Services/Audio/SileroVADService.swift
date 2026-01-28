import Foundation
import AVFoundation

/// Silero VAD service using sherpa-onnx
/// Detects whether audio contains speech (vs noise/silence)
class SileroVADService {
    static let shared = SileroVADService()
    
    private var vad: OpaquePointer?
    private var isInitialized = false
    
    private init() {}
    
    deinit {
        cleanup()
    }
    
    // MARK: - Initialization
    
    /// Initialize VAD with the Silero model
    func initialize() throws {
        guard !isInitialized else { return }
        
        guard let modelPath = vadModelPath() else {
            throw VADError.modelNotFound
        }
        
        var config = SherpaOnnxVadModelConfig()
        
        let modelPtr = strdup(modelPath)
        let providerPtr = strdup("cpu")
        
        defer {
            free(modelPtr)
            free(providerPtr)
        }
        
        // Silero VAD config
        config.silero_vad.model = UnsafePointer(modelPtr)
        config.silero_vad.threshold = 0.5           // Speech detection threshold
        config.silero_vad.min_silence_duration = 0.25  // Min silence to end segment (seconds)
        config.silero_vad.min_speech_duration = 0.1    // Min speech duration (seconds) - lowered for short utterances
        config.silero_vad.window_size = 512         // 32ms at 16kHz
        config.silero_vad.max_speech_duration = 30.0   // Max speech segment length
        
        config.sample_rate = 16000
        config.num_threads = 2
        config.provider = UnsafePointer(providerPtr)
        config.debug = 0
        
        vad = SherpaOnnxCreateVoiceActivityDetector(&config, 60.0)  // 60s buffer
        
        guard vad != nil else {
            throw VADError.initializationFailed
        }
        
        isInitialized = true
        print("SileroVAD: Initialized successfully")
    }
    
    /// Cleanup resources
    func cleanup() {
        if let vad = vad {
            SherpaOnnxDestroyVoiceActivityDetector(vad)
            self.vad = nil
        }
        isInitialized = false
    }
    
    // MARK: - Speech Detection
    
    func containsSpeech(fileURL: URL) -> Bool {
        do {
            if !isInitialized {
                try initialize()
            }
            
            guard let vad = vad else {
                print("SileroVAD: Not initialized, assuming speech")
                return true
            }
            
            let audioFile = try AVAudioFile(forReading: fileURL)
            let format = audioFile.processingFormat
            let frameCount = AVAudioFrameCount(audioFile.length)
            
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
                print("SileroVAD: Failed to create buffer, assuming speech")
                return true
            }
            
            try audioFile.read(into: buffer)
            
            guard let channelData = buffer.floatChannelData?[0] else {
                print("SileroVAD: No channel data, assuming speech")
                return true
            }
            
            let samples = Array(UnsafeBufferPointer(start: channelData, count: Int(buffer.frameLength)))
            
            SherpaOnnxVoiceActivityDetectorReset(vad)
            
            samples.withUnsafeBufferPointer { ptr in
                SherpaOnnxVoiceActivityDetectorAcceptWaveform(vad, ptr.baseAddress, Int32(samples.count))
            }
            
            SherpaOnnxVoiceActivityDetectorFlush(vad)
            
            let hasSpeech = SherpaOnnxVoiceActivityDetectorEmpty(vad) == 0
            let isDetected = SherpaOnnxVoiceActivityDetectorDetected(vad) == 1
            
            let result = hasSpeech || isDetected
            print("SileroVAD: Speech detected = \(result) (segments: \(hasSpeech), detected: \(isDetected))")
            
            return result
            
        } catch {
            print("SileroVAD: Error analyzing audio: \(error), assuming speech")
            return true  // On error, assume speech to avoid dropping valid recordings
        }
    }
    
    /// Check if audio samples contain speech
    /// - Parameters:
    ///   - samples: Float audio samples normalized to [-1, 1]
    ///   - sampleRate: Sample rate (should be 16000)
    /// - Returns: true if speech detected
    func containsSpeech(samples: [Float], sampleRate: Int = 16000) -> Bool {
        do {
            if !isInitialized {
                try initialize()
            }
            
            guard let vad = vad else {
                return true
            }
            
            // Reset VAD state
            SherpaOnnxVoiceActivityDetectorReset(vad)
            
            // Feed samples
            samples.withUnsafeBufferPointer { ptr in
                SherpaOnnxVoiceActivityDetectorAcceptWaveform(vad, ptr.baseAddress, Int32(samples.count))
            }
            
            // Flush
            SherpaOnnxVoiceActivityDetectorFlush(vad)
            
            // Check results
            let hasSpeech = SherpaOnnxVoiceActivityDetectorEmpty(vad) == 0
            let isDetected = SherpaOnnxVoiceActivityDetectorDetected(vad) == 1
            
            return hasSpeech || isDetected
            
        } catch {
            print("SileroVAD: Error: \(error)")
            return true
        }
    }
    
    // MARK: - Model Path
    
    private func vadModelPath() -> String? {
        let fm = FileManager.default
        let vadPath = AppDirectories.models.appendingPathComponent("silero_vad.onnx")
        
        if fm.fileExists(atPath: vadPath.path) {
            return vadPath.path
        }
        
        if let bundledPath = Bundle.main.resourceURL?.appendingPathComponent("Models/silero_vad.onnx"),
           fm.fileExists(atPath: bundledPath.path) {
            return bundledPath.path
        }
        
        print("SileroVAD: Model not found. Download from: https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/silero_vad.onnx")
        return nil
    }
    
    /// Check if VAD model is available
    var isModelAvailable: Bool {
        vadModelPath() != nil
    }
    
    /// Get model download URL
    static var modelDownloadURL: URL {
        URL(string: "https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/silero_vad.onnx")!
    }
    
    var expectedModelPath: URL {
        AppDirectories.models.appendingPathComponent("silero_vad.onnx")
    }
}

// MARK: - Errors

enum VADError: Error, LocalizedError {
    case modelNotFound
    case initializationFailed
    case analysisError
    
    var errorDescription: String? {
        switch self {
        case .modelNotFound:
            return "Silero VAD model not found. Please download silero_vad.onnx"
        case .initializationFailed:
            return "Failed to initialize Silero VAD"
        case .analysisError:
            return "Error analyzing audio for speech"
        }
    }
}
