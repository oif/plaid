import Foundation

// MARK: - ProcessedAudio

struct ProcessedAudio: Sendable {
    let samples: [Float]
    let sampleRate: Int
    let duration: TimeInterval
    let metrics: AudioMetrics
    let fileURL: URL?
    
    init(samples: [Float], sampleRate: Int = 16000, duration: TimeInterval, metrics: AudioMetrics, fileURL: URL? = nil) {
        self.samples = samples
        self.sampleRate = sampleRate
        self.duration = duration
        self.metrics = metrics
        self.fileURL = fileURL
    }
}

// MARK: - AudioMetrics

struct AudioMetrics: Sendable {
    let captureMs: Double
    let vadMs: Double
    let peakLevel: Float
    let avgLevel: Float
    
    static let zero = AudioMetrics(captureMs: 0, vadMs: 0, peakLevel: 0, avgLevel: 0)
}

// MARK: - VoiceContext

struct VoiceContext: Sendable {
    let appName: String?
    let bundleId: String?
    let documentType: String?
    let recentText: String?
    let vocabulary: [String]
    
    init(appName: String? = nil, bundleId: String? = nil, documentType: String? = nil, recentText: String? = nil, vocabulary: [String] = []) {
        self.appName = appName
        self.bundleId = bundleId
        self.documentType = documentType
        self.recentText = recentText
        self.vocabulary = vocabulary
    }
    
    static let empty = VoiceContext()
}

// MARK: - VoiceResult

struct VoiceResult: Sendable {
    let language: String?
    let text: String
    let rawText: String?
    let metrics: VoiceMetrics
}

// MARK: - VoiceMetrics

struct VoiceMetrics: Sendable {
    let sttMs: Double
    let llmMs: Double?
    let totalMs: Double
    
    init(sttMs: Double, llmMs: Double? = nil, totalMs: Double? = nil) {
        self.sttMs = sttMs
        self.llmMs = llmMs
        self.totalMs = totalMs ?? (sttMs + (llmMs ?? 0))
    }
}
