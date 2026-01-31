import Foundation
import Combine
import os.log

private let logger = Logger(subsystem: "com.neospaceindustries.plaid", category: "Speech")

struct TranscriptionResult {
    let originalText: String
    let processedText: String
    let sttDuration: Double
    let llmDuration: Double?
    let recordingDuration: Double?
    let sttProvider: String
    let appContext: AppContext?
    
    var finalText: String { processedText }
    var wasEnhanced: Bool { llmDuration != nil || originalText != processedText }
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
        let recDuration = recordingStartTime.map { Date().timeIntervalSince($0) }
        
        let appContext = contextService.getCurrentContext()
        
        let sttStart = Date()
        let sttResult = try await sttService.stopListening(context: appContext)
        let wallDuration = Date().timeIntervalSince(sttStart)
        
        logger.info("STT completed in \(String(format: "%.2f", wallDuration), privacy: .public)s, text length=\(sttResult.text.count, privacy: .public)")
        
        let result = try await buildTranscriptionResult(
            sttResult: sttResult,
            wallDuration: wallDuration,
            recordingDuration: recDuration,
            settings: settings,
            appContext: appContext
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
        let sttResult = try await sttService.transcribeFile(at: url, context: appContext)
        let wallDuration = Date().timeIntervalSince(sttStart)
        
        let result = try await buildTranscriptionResult(
            sttResult: sttResult,
            wallDuration: wallDuration,
            recordingDuration: nil,
            settings: settings,
            appContext: appContext
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
    
    private func buildTranscriptionResult(
        sttResult: STTResult,
        wallDuration: Double,
        recordingDuration: Double?,
        settings: AppSettings,
        appContext: AppContext
    ) async throws -> TranscriptionResult {
        if sttResult.isCloudCorrected {
            let originalText = sttResult.original ?? sttResult.text
            let sttDuration = sttResult.durationMs.map { Double($0) / 1000.0 } ?? wallDuration
            
            return TranscriptionResult(
                originalText: originalText,
                processedText: sttResult.text,
                sttDuration: sttDuration,
                llmDuration: nil,
                recordingDuration: recordingDuration,
                sttProvider: settings.sttProvider.rawValue,
                appContext: appContext
            )
        }
        
        let originalText = sttResult.text
        let sttDuration = wallDuration
        
        guard Self.hasSubstantiveContent(originalText) else {
            logger.warning("No substantive content in STT result: '\(originalText, privacy: .public)'")
            return TranscriptionResult(
                originalText: originalText,
                processedText: "",
                sttDuration: sttDuration,
                llmDuration: nil,
                recordingDuration: recordingDuration,
                sttProvider: settings.sttProvider.rawValue,
                appContext: appContext
            )
        }
        
        var processedText = originalText
        var llmDuration: Double? = nil
        
        if settings.enableLLMCorrection && !settings.effectiveLLMApiKey.isEmpty {
            let llmStart = Date()
            let messages = Self.buildMessages(text: originalText, settings: settings, context: appContext)
            processedText = try await llmService.process(messages: messages)
            llmDuration = Date().timeIntervalSince(llmStart)
        }
        
        return TranscriptionResult(
            originalText: originalText,
            processedText: processedText,
            sttDuration: sttDuration,
            llmDuration: llmDuration,
            recordingDuration: recordingDuration,
            sttProvider: settings.sttProvider.rawValue,
            appContext: appContext
        )
    }
    
    private static func hasSubstantiveContent(_ text: String) -> Bool {
        let stripped = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !stripped.isEmpty else { return false }
        return stripped.contains(where: { $0.isLetter || $0.isNumber })
    }
    
    private static func buildMessages(text: String, settings: AppSettings, context: AppContext) -> [[String: String]] {
        var systemPrompt = settings.customSystemPrompt
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        let builtIn = ["Plaid"]
        let vocab = builtIn + settings.customVocabulary.filter { !builtIn.contains($0) }
        systemPrompt += "\n\n**参考词表（优先使用这些拼写）：**\n" + vocab.joined(separator: "、")
        
        var userPrompt = settings.customUserPrompt
        var contextParts: [String] = []
        if let appName = context.appName {
            contextParts.append("当前应用：\(appName)")
        }
        if let element = context.focusedElement {
            contextParts.append("输入位置：\(element)")
        }
        if contextParts.isEmpty {
            userPrompt = userPrompt.replacingOccurrences(of: "{{context}}", with: "")
        } else {
            let contextBlock = "**上下文：**\n" + contextParts.joined(separator: "\n")
            userPrompt = userPrompt.replacingOccurrences(of: "{{context}}", with: contextBlock)
        }
        userPrompt = userPrompt.replacingOccurrences(of: "{{text}}", with: text)
        userPrompt = userPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return [
            ["role": "system", "content": systemPrompt],
            ["role": "user", "content": userPrompt]
        ]
    }
    
    private func saveToHistory(_ result: TranscriptionResult) {
        guard !result.originalText.isEmpty else { return }
        
        TranscriptionHistoryService.shared.addRecord(
            originalText: result.originalText,
            correctedText: result.wasEnhanced ? result.processedText : nil,
            sttProvider: result.sttProvider,
            sttDuration: result.sttDuration,
            llmDuration: result.llmDuration,
            recordingDuration: result.recordingDuration,
            appName: result.appContext?.appName,
            bundleId: result.appContext?.bundleId
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
