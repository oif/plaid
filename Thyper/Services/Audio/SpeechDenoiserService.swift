import Foundation
import AVFoundation

class SpeechDenoiserService {
    static let shared = SpeechDenoiserService()
    
    private var denoiser: OpaquePointer?
    private var isInitialized = false
    
    private init() {}
    
    deinit {
        cleanup()
    }
    
    func initialize() throws {
        guard !isInitialized else { return }
        
        guard let modelPath = denoiserModelPath() else {
            throw DenoiserError.modelNotFound
        }
        
        var config = SherpaOnnxOfflineSpeechDenoiserConfig()
        
        let modelPtr = strdup(modelPath)
        let providerPtr = strdup("cpu")
        
        defer {
            free(modelPtr)
            free(providerPtr)
        }
        
        config.model.gtcrn.model = UnsafePointer(modelPtr)
        config.model.num_threads = 2
        config.model.debug = 0
        config.model.provider = UnsafePointer(providerPtr)
        
        denoiser = SherpaOnnxCreateOfflineSpeechDenoiser(&config)
        
        guard denoiser != nil else {
            throw DenoiserError.initializationFailed
        }
        
        isInitialized = true
        print("SpeechDenoiser: Initialized with gtcrn_simple model")
    }
    
    func cleanup() {
        if let denoiser = denoiser {
            SherpaOnnxDestroyOfflineSpeechDenoiser(denoiser)
            self.denoiser = nil
        }
        isInitialized = false
    }
    
    func denoise(fileURL: URL) throws -> URL {
        if !isInitialized {
            try initialize()
        }
        
        guard let denoiser = denoiser else {
            throw DenoiserError.notInitialized
        }
        
        let audioFile = try AVAudioFile(forReading: fileURL)
        let format = audioFile.processingFormat
        let frameCount = AVAudioFrameCount(audioFile.length)
        
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw DenoiserError.audioReadError
        }
        
        try audioFile.read(into: buffer)
        
        guard let channelData = buffer.floatChannelData?[0] else {
            throw DenoiserError.audioReadError
        }
        
        let samples = Array(UnsafeBufferPointer(start: channelData, count: Int(buffer.frameLength)))
        let sampleRate = Int32(format.sampleRate)
        
        let denoisedAudio = samples.withUnsafeBufferPointer { ptr -> OpaquePointer? in
            let result = SherpaOnnxOfflineSpeechDenoiserRun(
                denoiser,
                ptr.baseAddress,
                Int32(samples.count),
                sampleRate
            )
            return OpaquePointer(result)
        }
        
        guard let result = denoisedAudio else {
            throw DenoiserError.processingFailed
        }
        
        let denoisedPtr = UnsafePointer<SherpaOnnxDenoisedAudio>(result)
        defer {
            SherpaOnnxDestroyDenoisedAudio(denoisedPtr)
        }
        
        let outputSamples = Array(UnsafeBufferPointer(
            start: denoisedPtr.pointee.samples,
            count: Int(denoisedPtr.pointee.n)
        ))
        let outputSampleRate = denoisedPtr.pointee.sample_rate
        
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("thyper_denoised_\(UUID().uuidString).wav")
        
        try writeWavFile(samples: outputSamples, sampleRate: Int(outputSampleRate), to: outputURL)
        
        print("SpeechDenoiser: Processed \(samples.count) samples -> \(outputSamples.count) samples")
        
        return outputURL
    }
    
    func denoise(samples: [Float], sampleRate: Int) throws -> [Float] {
        if !isInitialized {
            try initialize()
        }
        
        guard let denoiser = denoiser else {
            throw DenoiserError.notInitialized
        }
        
        let denoisedAudio = samples.withUnsafeBufferPointer { ptr -> OpaquePointer? in
            let result = SherpaOnnxOfflineSpeechDenoiserRun(
                denoiser,
                ptr.baseAddress,
                Int32(samples.count),
                Int32(sampleRate)
            )
            return OpaquePointer(result)
        }
        
        guard let result = denoisedAudio else {
            throw DenoiserError.processingFailed
        }
        
        let denoisedPtr = UnsafePointer<SherpaOnnxDenoisedAudio>(result)
        defer {
            SherpaOnnxDestroyDenoisedAudio(denoisedPtr)
        }
        
        return Array(UnsafeBufferPointer(
            start: denoisedPtr.pointee.samples,
            count: Int(denoisedPtr.pointee.n)
        ))
    }
    
    private func writeWavFile(samples: [Float], sampleRate: Int, to url: URL) throws {
        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: Double(sampleRate),
            channels: 1,
            interleaved: false
        )!
        
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)) else {
            throw DenoiserError.audioWriteError
        }
        
        buffer.frameLength = AVAudioFrameCount(samples.count)
        
        if let channelData = buffer.floatChannelData?[0] {
            for i in 0..<samples.count {
                channelData[i] = samples[i]
            }
        }
        
        let outputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ]
        
        let outputFile = try AVAudioFile(forWriting: url, settings: outputSettings)
        try outputFile.write(from: buffer)
    }
    
    private func denoiserModelPath() -> String? {
        let fm = FileManager.default
        
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let modelsDir = appSupport.appendingPathComponent("Thyper/Models")
        let modelPath = modelsDir.appendingPathComponent("gtcrn_simple.onnx")
        
        if fm.fileExists(atPath: modelPath.path) {
            return modelPath.path
        }
        
        if let bundledPath = Bundle.main.resourceURL?.appendingPathComponent("Models/gtcrn_simple.onnx"),
           fm.fileExists(atPath: bundledPath.path) {
            return bundledPath.path
        }
        
        let devPath = "/Users/neo/Desktop/thyper/Models/gtcrn_simple.onnx"
        if fm.fileExists(atPath: devPath) {
            return devPath
        }
        
        print("SpeechDenoiser: Model not found")
        return nil
    }
    
    var isModelAvailable: Bool {
        denoiserModelPath() != nil
    }
}

enum DenoiserError: Error, LocalizedError {
    case modelNotFound
    case initializationFailed
    case notInitialized
    case audioReadError
    case audioWriteError
    case processingFailed
    
    var errorDescription: String? {
        switch self {
        case .modelNotFound: return "Denoiser model not found"
        case .initializationFailed: return "Failed to initialize denoiser"
        case .notInitialized: return "Denoiser not initialized"
        case .audioReadError: return "Failed to read audio"
        case .audioWriteError: return "Failed to write audio"
        case .processingFailed: return "Denoising failed"
        }
    }
}
