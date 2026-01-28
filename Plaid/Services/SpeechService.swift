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
    private let contextService = AppContextService()
    
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
    
    private var waveformLevelBuffer = [Float](repeating: 0.1, count: 12)
    
    private func updateWaveform(from samples: [Float]) {
        guard isListening else { return }
        let count = 12
        if samples.count >= count {
            let start = samples.count - count
            for i in 0..<count { waveformLevelBuffer[i] = samples[start + i] }
        } else {
            for i in 0..<samples.count { waveformLevelBuffer[i] = samples[i] }
            for i in samples.count..<count { waveformLevelBuffer[i] = 0.1 }
        }
        waveformLevels = waveformLevelBuffer
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
        
        // Capture app context NOW, before STT processing changes focus
        let appContext = contextService.getCurrentContext()
        
        let sttStart = Date()
        let originalText = try await sttService.stopListening()
        let sttDuration = Date().timeIntervalSince(sttStart)
        
        let hasContent = Self.hasSubstantiveContent(originalText)
        
        guard hasContent else {
            return TranscriptionResult(
                originalText: originalText,
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
            let systemPrompt = Self.buildSystemPrompt(settings: settings, context: appContext)
            processedText = try await llmService.process(originalText, systemPrompt: systemPrompt)
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
        let appContext = contextService.getCurrentContext()
        
        let sttStart = Date()
        let originalText = try await sttService.transcribeFile(at: url)
        let sttDuration = Date().timeIntervalSince(sttStart)
        
        let hasContent = Self.hasSubstantiveContent(originalText)
        
        guard hasContent else {
            return TranscriptionResult(
                originalText: originalText,
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
            let systemPrompt = Self.buildSystemPrompt(settings: settings, context: appContext)
            processedText = try await llmService.process(originalText, systemPrompt: systemPrompt)
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
    
    private static func hasSubstantiveContent(_ text: String) -> Bool {
        let stripped = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !stripped.isEmpty else { return false }
        return stripped.contains(where: { $0.isLetter || $0.isNumber })
    }
    
    private static func buildSystemPrompt(settings: AppSettings, context: AppContext) -> String {
        var prompt = settings.customPrompt
        
        // Inject app context
        var contextParts: [String] = []
        if let appName = context.appName {
            contextParts.append("当前应用：\(appName)")
        }
        if let element = context.focusedElement {
            contextParts.append("输入位置：\(element)")
        }
        if contextParts.isEmpty {
            prompt = prompt.replacingOccurrences(of: "{{context}}", with: "")
        } else {
            let contextBlock = "\n**上下文：**\n" + contextParts.joined(separator: "\n")
            prompt = prompt.replacingOccurrences(of: "{{context}}", with: contextBlock)
        }
        
        // Inject vocabulary
        let vocab = settings.customVocabulary
        if vocab.isEmpty {
            prompt = prompt.replacingOccurrences(of: "{{vocabulary}}", with: "")
        } else {
            let vocabBlock = "\n**参考词表（优先使用这些拼写）：**\n" + vocab.joined(separator: "、")
            prompt = prompt.replacingOccurrences(of: "{{vocabulary}}", with: vocabBlock)
        }
        
        // Clean up legacy {{text}} placeholder for users with old custom prompts
        prompt = prompt.replacingOccurrences(of: "{{text}}", with: "")
        
        return prompt.trimmingCharacters(in: .whitespacesAndNewlines)
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
