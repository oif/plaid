import Foundation
import AVFoundation

/// Swift wrapper for sherpa-onnx offline speech recognition
/// Uses the sherpa-onnx C API to perform local STT without network calls
class SherpaOnnxService {
    
    private var recognizer: OpaquePointer?
    private var currentModelType: ModelType?
    private var currentModel: LocalModel?  // Track which model is loaded for caching
    private var isInitialized = false
    private var isInitializing = false  // Prevent concurrent initialization
    
    static let shared = SherpaOnnxService()
    
    private init() {}
    
    deinit {
        cleanup()
    }
    
    // MARK: - Initialization
    
    /// Initialize the recognizer with a specific model
    /// - Parameter model: The local model to use
    /// - Throws: SherpaError if initialization fails
    func initialize(with model: LocalModel) throws {
        // Skip if already initialized with the same model (caching)
        if isInitialized && currentModel == model && recognizer != nil {
            print("SherpaOnnx: Model \(model.displayName) already loaded, reusing")
            return
        }
        
        // Prevent concurrent initialization
        guard !isInitializing else {
            print("SherpaOnnx: Already initializing, skipping")
            return
        }
        isInitializing = true
        defer { isInitializing = false }
        
        // Clean up any existing recognizer
        cleanup()
        
        guard let modelFiles = ModelManager.shared.getModelFiles(model) else {
            throw SherpaError.modelNotFound
        }
        
        // Verify files exist
        let fm = FileManager.default
        guard fm.fileExists(atPath: modelFiles.tokensPath) else {
            throw SherpaError.tokensFileNotFound
        }
        
        switch model.modelType {
        case .sensevoice:
            guard fm.fileExists(atPath: modelFiles.modelPath) else {
                throw SherpaError.modelFileNotFound
            }
            try initializeSenseVoice(modelPath: modelFiles.modelPath, tokensPath: modelFiles.tokensPath, model: model)
            
        case .whisper:
            guard let encoderPath = modelFiles.encoderPath,
                  let decoderPath = modelFiles.decoderPath,
                  fm.fileExists(atPath: encoderPath),
                  fm.fileExists(atPath: decoderPath) else {
                throw SherpaError.modelFileNotFound
            }
            try initializeWhisper(encoderPath: encoderPath, decoderPath: decoderPath, tokensPath: modelFiles.tokensPath)
        }
        
        currentModelType = model.modelType
        currentModel = model
        isInitialized = true
        print("SherpaOnnx: Initialized with model \(model.displayName)")
    }
    
    private func initializeSenseVoice(modelPath: String, tokensPath: String, model: LocalModel) throws {
        var config = SherpaOnnxOfflineRecognizerConfig()
        
        config.feat_config.sample_rate = 16000
        config.feat_config.feature_dim = 80
        
        let tokensPtr = strdup(tokensPath)
        let providerPtr = strdup("cpu")
        let modelTypePtr = strdup("sense_voice")
        let senseModelPtr = strdup(modelPath)
        let langPtr = strdup("auto")
        let decodingPtr = strdup("greedy_search")
        
        defer {
            free(tokensPtr)
            free(providerPtr)
            free(modelTypePtr)
            free(senseModelPtr)
            free(langPtr)
            free(decodingPtr)
        }
        
        config.model_config.tokens = UnsafePointer(tokensPtr)
        config.model_config.num_threads = 4
        config.model_config.debug = 0
        config.model_config.provider = UnsafePointer(providerPtr)
        config.model_config.model_type = UnsafePointer(modelTypePtr)
        
        config.model_config.sense_voice.model = UnsafePointer(senseModelPtr)
        config.model_config.sense_voice.language = UnsafePointer(langPtr)
        config.model_config.sense_voice.use_itn = 1
        
        config.decoding_method = UnsafePointer(decodingPtr)
        
        recognizer = SherpaOnnxCreateOfflineRecognizer(&config)
        
        guard recognizer != nil else {
            throw SherpaError.initializationFailed
        }
    }
    
    private func initializeWhisper(encoderPath: String, decoderPath: String, tokensPath: String) throws {
        var config = SherpaOnnxOfflineRecognizerConfig()
        
        config.feat_config.sample_rate = 16000
        config.feat_config.feature_dim = 80
        
        let tokensPtr = strdup(tokensPath)
        let providerPtr = strdup("cpu")
        let modelTypePtr = strdup("whisper")
        let encoderPtr = strdup(encoderPath)
        let decoderPtr = strdup(decoderPath)
        let langPtr = strdup("auto")
        let taskPtr = strdup("transcribe")
        let decodingPtr = strdup("greedy_search")
        
        defer {
            free(tokensPtr)
            free(providerPtr)
            free(modelTypePtr)
            free(encoderPtr)
            free(decoderPtr)
            free(langPtr)
            free(taskPtr)
            free(decodingPtr)
        }
        
        config.model_config.tokens = UnsafePointer(tokensPtr)
        config.model_config.num_threads = 4
        config.model_config.debug = 0
        config.model_config.provider = UnsafePointer(providerPtr)
        config.model_config.model_type = UnsafePointer(modelTypePtr)
        
        config.model_config.whisper.encoder = UnsafePointer(encoderPtr)
        config.model_config.whisper.decoder = UnsafePointer(decoderPtr)
        config.model_config.whisper.language = UnsafePointer(langPtr)
        config.model_config.whisper.task = UnsafePointer(taskPtr)
        config.model_config.whisper.tail_paddings = -1
        
        config.decoding_method = UnsafePointer(decodingPtr)
        
        recognizer = SherpaOnnxCreateOfflineRecognizer(&config)
        
        guard recognizer != nil else {
            throw SherpaError.initializationFailed
        }
    }
    
    // MARK: - Transcription
    
    /// Transcribe audio data
    /// - Parameters:
    ///   - audioData: Raw audio data (16-bit PCM)
    ///   - sampleRate: Sample rate of the audio (will be resampled to 16kHz if different)
    /// - Returns: Transcribed text
    /// - Throws: SherpaError if transcription fails
    func transcribe(audioData: Data, sampleRate: Int = 16000) throws -> String {
        guard isInitialized, let recognizer = recognizer else {
            throw SherpaError.notInitialized
        }
        
        // Convert Data to float samples (normalized to [-1, 1])
        let samples = audioDataToFloatSamples(audioData)
        
        guard !samples.isEmpty else {
            throw SherpaError.emptyAudio
        }
        
        return try transcribe(samples: samples, sampleRate: Int32(sampleRate))
    }
    
    /// Transcribe audio file
    /// - Parameter fileURL: URL to the audio file (WAV format preferred)
    /// - Returns: Transcribed text
    /// - Throws: SherpaError if transcription fails
    func transcribe(fileURL: URL) throws -> String {
        guard isInitialized, let recognizer = recognizer else {
            throw SherpaError.notInitialized
        }
        
        // Read audio file
        let audioFile = try AVAudioFile(forReading: fileURL)
        let format = audioFile.processingFormat
        let frameCount = AVAudioFrameCount(audioFile.length)
        
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw SherpaError.audioReadError
        }
        
        try audioFile.read(into: buffer)
        
        // Convert to float samples
        guard let channelData = buffer.floatChannelData?[0] else {
            throw SherpaError.audioReadError
        }
        
        let samples = Array(UnsafeBufferPointer(start: channelData, count: Int(buffer.frameLength)))
        let sampleRate = Int32(format.sampleRate)
        
        return try transcribe(samples: samples, sampleRate: sampleRate)
    }
    
    /// Transcribe float samples directly
    /// - Parameters:
    ///   - samples: Array of float samples normalized to [-1, 1]
    ///   - sampleRate: Sample rate of the audio
    /// - Returns: Transcribed text
    func transcribe(samples: [Float], sampleRate: Int32) throws -> String {
        guard let recognizer = recognizer else {
            throw SherpaError.notInitialized
        }
        
        // Create stream
        guard let stream = SherpaOnnxCreateOfflineStream(recognizer) else {
            throw SherpaError.streamCreationFailed
        }
        
        defer {
            SherpaOnnxDestroyOfflineStream(stream)
        }
        
        // Accept waveform
        samples.withUnsafeBufferPointer { bufferPointer in
            SherpaOnnxAcceptWaveformOffline(stream, sampleRate, bufferPointer.baseAddress, Int32(samples.count))
        }
        
        // Decode
        SherpaOnnxDecodeOfflineStream(recognizer, stream)
        
        // Get result
        guard let result = SherpaOnnxGetOfflineStreamResult(stream) else {
            throw SherpaError.noResult
        }
        
        defer {
            SherpaOnnxDestroyOfflineRecognizerResult(result)
        }
        
        guard let textPtr = result.pointee.text else {
            return ""
        }
        
        let text = String(cString: textPtr)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Helpers
    
    /// Convert 16-bit PCM audio data to float samples
    private func audioDataToFloatSamples(_ data: Data) -> [Float] {
        let int16Count = data.count / 2
        var samples = [Float](repeating: 0, count: int16Count)
        
        data.withUnsafeBytes { rawBufferPointer in
            let int16Buffer = rawBufferPointer.bindMemory(to: Int16.self)
            for i in 0..<int16Count {
                samples[i] = Float(int16Buffer[i]) / Float(Int16.max)
            }
        }
        
        return samples
    }
    
    /// Cleanup resources
    func cleanup() {
        if let recognizer = recognizer {
            SherpaOnnxDestroyOfflineRecognizer(recognizer)
            self.recognizer = nil
        }
        isInitialized = false
        currentModelType = nil
        currentModel = nil
    }
    
    /// Initialize asynchronously in background for preloading
    func initializeAsync(with model: LocalModel) async throws {
        try await Task.detached(priority: .userInitiated) {
            try self.initialize(with: model)
        }.value
    }
    
    /// Warm up the model with a tiny transcription for faster first response
    func warmup() {
        guard isInitialized, recognizer != nil else { return }
        let sampleRate: Int32 = 16000
        let samples = [Float](repeating: 0.0001, count: Int(sampleRate) / 10)
        
        do {
            _ = try transcribe(samples: samples, sampleRate: sampleRate)
            print("SherpaOnnx: Warmup complete")
        } catch {
            print("SherpaOnnx: Warmup skipped - \(error)")
        }
    }
    
    /// Check if the service is ready to transcribe
    var isReady: Bool {
        isInitialized && recognizer != nil
    }
    
    /// Get the current model type
    var modelType: ModelType? {
        currentModelType
    }
}

// MARK: - Errors

enum SherpaError: Error, LocalizedError {
    case notInitialized
    case modelNotFound
    case modelFileNotFound
    case tokensFileNotFound
    case initializationFailed
    case streamCreationFailed
    case emptyAudio
    case audioReadError
    case noResult
    
    var errorDescription: String? {
        switch self {
        case .notInitialized: return "SherpaOnnx not initialized"
        case .modelNotFound: return "Model not found"
        case .modelFileNotFound: return "Model file not found"
        case .tokensFileNotFound: return "Tokens file not found"
        case .initializationFailed: return "Failed to initialize recognizer"
        case .streamCreationFailed: return "Failed to create audio stream"
        case .emptyAudio: return "Empty audio data"
        case .audioReadError: return "Failed to read audio file"
        case .noResult: return "No transcription result"
        }
    }
}
