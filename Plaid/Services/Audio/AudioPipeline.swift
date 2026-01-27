import Foundation
import AVFoundation

@MainActor
class AudioPipeline: ObservableObject {
    
    struct Config {
        var targetSampleRate: Int = 16000
    }
    
    @Published private(set) var audioLevel: Float = 0
    @Published private(set) var waveformSamples: [Float] = []
    
    weak var delegate: AudioPipelineDelegate?
    
    private var audioEngine: AVAudioEngine?
    private var vadProcessor: VADProcessor
    private var config: Config
    
    private var accumulatedSamples: [Float] = []
    private var recordingStartTime: Date?
    private var tempFileURL: URL?
    private var audioFile: AVAudioFile?
    private var sampleCollectionCounter: Int = 0
    
    init(config: Config = Config()) {
        self.config = config
        self.vadProcessor = VADProcessor()
    }
    
    func updateConfig(_ config: Config) {
        self.config = config
    }
    
    func start() async throws {
        cleanup()
        
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else {
            throw AudioPipelineError.engineCreationFailed
        }
        
        recordingStartTime = Date()
        accumulatedSamples = []
        waveformSamples = []
        sampleCollectionCounter = 0
        
        let tempDir = FileManager.default.temporaryDirectory
        tempFileURL = tempDir.appendingPathComponent("thyper_\(UUID().uuidString).wav")
        
        guard let fileURL = tempFileURL else {
            throw AudioPipelineError.fileCreationFailed
        }
        
        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        
        let outputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: config.targetSampleRate,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ]
        
        audioFile = try AVAudioFile(forWriting: fileURL, settings: outputSettings)
        
        let outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: Double(config.targetSampleRate),
            channels: 1,
            interleaved: false
        )!
        
        guard let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
            throw AudioPipelineError.converterCreationFailed
        }
        
        vadProcessor.start()
        
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            guard let self = self else { return }
            
            let vadResult = self.vadProcessor.process(buffer: buffer)
            
            Task { @MainActor in
                let normalizedLevel = min(1.0, vadResult.level * 5)
                self.audioLevel = normalizedLevel
                self.delegate?.audioPipeline(self, didUpdateLevel: normalizedLevel)
                
                self.sampleCollectionCounter += 1
                if self.sampleCollectionCounter % 3 == 0 {
                    let normalizedSample = min(1.0, vadResult.peakLevel * 3)
                    self.waveformSamples.append(normalizedSample)
                    if self.waveformSamples.count > 200 {
                        self.waveformSamples.removeFirst()
                    }
                    self.delegate?.audioPipeline(self, didUpdateWaveform: self.waveformSamples)
                }
            }
            
            let frameCount = AVAudioFrameCount(Double(buffer.frameLength) * Double(self.config.targetSampleRate) / inputFormat.sampleRate)
            guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: frameCount) else { return }
            
            var error: NSError?
            converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
                outStatus.pointee = .haveData
                return buffer
            }
            
            if error == nil, let audioFile = self.audioFile {
                try? audioFile.write(from: convertedBuffer)
            }
            
            if let channelData = convertedBuffer.floatChannelData?[0] {
                let samples = Array(UnsafeBufferPointer(start: channelData, count: Int(convertedBuffer.frameLength)))
                self.accumulatedSamples.append(contentsOf: samples)
            }
        }
        
        audioEngine.prepare()
        try audioEngine.start()
    }
    
    func stop() async throws -> ProcessedAudio {
        let captureEnd = Date()
        let captureMs = recordingStartTime.map { captureEnd.timeIntervalSince($0) * 1000 } ?? 0
        
        audioEngine?.stop()
        if audioEngine?.inputNode.numberOfInputs ?? 0 > 0 {
            audioEngine?.inputNode.removeTap(onBus: 0)
        }
        
        vadProcessor.reset()
        
        let duration = recordingStartTime.map { captureEnd.timeIntervalSince($0) } ?? 0
        let avgLevel = accumulatedSamples.isEmpty ? 0 : accumulatedSamples.reduce(0) { $0 + abs($1) } / Float(accumulatedSamples.count)
        let peakLevel = accumulatedSamples.max() ?? 0
        
        let metrics = AudioMetrics(
            captureMs: captureMs,
            vadMs: 0,
            peakLevel: peakLevel,
            avgLevel: avgLevel
        )
        
        let result = ProcessedAudio(
            samples: accumulatedSamples,
            sampleRate: config.targetSampleRate,
            duration: duration,
            metrics: metrics,
            fileURL: tempFileURL
        )
        
        audioEngine = nil
        audioFile = nil
        audioLevel = 0
        
        return result
    }
    
    func cancel() {
        cleanup()
    }
    
    private func cleanup() {
        audioEngine?.stop()
        if audioEngine?.inputNode.numberOfInputs ?? 0 > 0 {
            audioEngine?.inputNode.removeTap(onBus: 0)
        }
        audioEngine = nil
        audioFile = nil
        
        vadProcessor.reset()
        
        accumulatedSamples = []
        audioLevel = 0
        waveformSamples = []
        sampleCollectionCounter = 0
        recordingStartTime = nil
        
        if let url = tempFileURL {
            try? FileManager.default.removeItem(at: url)
            tempFileURL = nil
        }
    }
}

enum AudioPipelineError: Error, LocalizedError {
    case engineCreationFailed
    case fileCreationFailed
    case converterCreationFailed
    case notRecording
    
    var errorDescription: String? {
        switch self {
        case .engineCreationFailed: return "Failed to create audio engine"
        case .fileCreationFailed: return "Failed to create audio file"
        case .converterCreationFailed: return "Failed to create audio converter"
        case .notRecording: return "Not recording"
        }
    }
}
