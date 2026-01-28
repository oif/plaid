import Foundation
import Combine

struct TranscriptionResult {
    let originalText: String
    let processedText: String
    let sttDuration: Double
    let llmDuration: Double?
    let sttProvider: String
    
    var finalText: String { processedText }
    var wasEnhanced: Bool { llmDuration != nil }
}

@MainActor
class SpeechService: ObservableObject {
    static let shared = SpeechService()
    
    private let sttService = STTService()
    private let llmService = LLMService()
    
    @Published var isListening = false
    @Published var isProcessing = false
    @Published var waveformLevels: [Float] = Array(repeating: 0.1, count: 12)
    @Published var audioLevel: Float = 0
    
    var onPartialTranscription: ((String) -> Void)?
    
    private var cancellables = Set<AnyCancellable>()
    private var recordingStartTime: Date?
    
    private init() {
        sttService.$audioLevel
            .receive(on: RunLoop.main)
            .assign(to: &$audioLevel)
        
        sttService.$waveformSamples
            .throttle(for: 0.05, scheduler: RunLoop.main, latest: true)
            .sink { [weak self] samples in
                self?.updateWaveform(from: samples)
            }
            .store(in: &cancellables)
    }
    
    private func updateWaveform(from samples: [Float]) {
        guard isListening else { return }
        let count = 12
        if samples.count >= count {
            waveformLevels = Array(samples.suffix(count))
        } else {
            waveformLevels = samples + Array(repeating: 0.1, count: count - samples.count)
        }
    }
    
    func initialize() async throws {
        try await sttService.initialize()
    }
    
    func startListening(onPartial: ((String) -> Void)? = nil) async throws {
        guard !isListening else { return }
        
        isListening = true
        recordingStartTime = Date()
        onPartialTranscription = onPartial
        
        try await sttService.startListening { [weak self] partial in
            Task { @MainActor in
                self?.onPartialTranscription?(partial)
            }
        }
    }
    
    func stopListening() async throws -> TranscriptionResult {
        guard isListening else {
            throw SpeechError.notListening
        }
        
        isListening = false
        isProcessing = true
        waveformLevels = Array(repeating: 0.1, count: 12)
        
        defer { isProcessing = false }
        
        let settings = AppSettings.shared
        
        let sttStart = Date()
        let originalText = try await sttService.stopListening()
        let sttDuration = Date().timeIntervalSince(sttStart)
        
        guard !originalText.isEmpty else {
            return TranscriptionResult(
                originalText: "",
                processedText: "",
                sttDuration: sttDuration,
                llmDuration: nil,
                sttProvider: settings.sttProvider.rawValue
            )
        }
        
        var processedText = originalText
        var llmDuration: Double? = nil
        
        if settings.enableLLMCorrection && !settings.effectiveLLMApiKey.isEmpty {
            let llmStart = Date()
            let prompt = Self.buildPrompt(settings: settings, text: originalText)
            processedText = try await llmService.process(originalText, systemPrompt: prompt)
            llmDuration = Date().timeIntervalSince(llmStart)
        }
        
        let result = TranscriptionResult(
            originalText: originalText,
            processedText: processedText,
            sttDuration: sttDuration,
            llmDuration: llmDuration,
            sttProvider: settings.sttProvider.rawValue
        )
        
        saveToHistory(result)
        
        return result
    }
    
    func transcribeFile(at url: URL) async throws -> TranscriptionResult {
        guard !isListening && !isProcessing else {
            throw SpeechError.busy
        }
        
        isProcessing = true
        defer { isProcessing = false }
        
        let settings = AppSettings.shared
        
        let sttStart = Date()
        let originalText = try await sttService.transcribeFile(at: url)
        let sttDuration = Date().timeIntervalSince(sttStart)
        
        guard !originalText.isEmpty else {
            return TranscriptionResult(
                originalText: "",
                processedText: "",
                sttDuration: sttDuration,
                llmDuration: nil,
                sttProvider: settings.sttProvider.rawValue
            )
        }
        
        var processedText = originalText
        var llmDuration: Double? = nil
        
        if settings.enableLLMCorrection && !settings.effectiveLLMApiKey.isEmpty {
            let llmStart = Date()
            let prompt = Self.buildPrompt(settings: settings, text: originalText)
            processedText = try await llmService.process(originalText, systemPrompt: prompt)
            llmDuration = Date().timeIntervalSince(llmStart)
        }
        
        let result = TranscriptionResult(
            originalText: originalText,
            processedText: processedText,
            sttDuration: sttDuration,
            llmDuration: llmDuration,
            sttProvider: settings.sttProvider.rawValue
        )
        
        saveToHistory(result)
        
        return result
    }
    
    func cancel() {
        if isListening {
            sttService.cancel()
        }
        isListening = false
        isProcessing = false
        waveformLevels = Array(repeating: 0.1, count: 12)
    }
    
    private static func buildPrompt(settings: AppSettings, text: String) -> String {
        var prompt = settings.customPrompt
        
        let vocab = settings.customVocabulary
        if vocab.isEmpty {
            prompt = prompt.replacingOccurrences(of: "{{vocabulary}}", with: "")
        } else {
            let vocabBlock = "\n**参考词表（优先使用这些拼写）：**\n" + vocab.joined(separator: "、")
            prompt = prompt.replacingOccurrences(of: "{{vocabulary}}", with: vocabBlock)
        }
        
        prompt = prompt.replacingOccurrences(of: "{{text}}", with: text)
        return prompt
    }
    
    private func saveToHistory(_ result: TranscriptionResult) {
        guard !result.originalText.isEmpty else { return }
        
        TranscriptionHistoryService.shared.addRecord(
            originalText: result.originalText,
            correctedText: result.wasEnhanced ? result.processedText : nil,
            sttProvider: result.sttProvider,
            sttDuration: result.sttDuration,
            llmDuration: result.llmDuration
        )
    }
}

enum SpeechError: Error, LocalizedError {
    case notListening
    case busy
    case sttFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .notListening: return "Not currently listening"
        case .busy: return "Speech service is busy"
        case .sttFailed(let msg): return "STT failed: \(msg)"
        }
    }
}
