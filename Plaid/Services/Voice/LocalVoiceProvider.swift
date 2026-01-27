import Foundation

final class LocalVoiceProvider: VoiceProvider, @unchecked Sendable {
    let name = "Local"
    let isLocal = true
    
    private let sherpa = SherpaOnnxService.shared
    
    func process(
        audio: ProcessedAudio,
        context: VoiceContext,
        mode: VoiceMode
    ) async throws -> VoiceResult {
        let totalStart = Date()
        
        guard sherpa.isReady else {
            throw VoiceProviderError.notInitialized
        }
        
        let sttStart = Date()
        let rawText: String
        do {
            rawText = try sherpa.transcribe(samples: audio.samples, sampleRate: Int32(audio.sampleRate))
        } catch {
            throw VoiceProviderError.transcriptionFailed(error.localizedDescription)
        }
        let sttMs = Date().timeIntervalSince(sttStart) * 1000
        
        guard !rawText.isEmpty else {
            return VoiceResult(
                language: nil,
                text: "",
                rawText: nil,
                metrics: VoiceMetrics(sttMs: sttMs)
            )
        }
        
        if mode.skipLLM {
            let totalMs = Date().timeIntervalSince(totalStart) * 1000
            return VoiceResult(
                language: nil,
                text: rawText,
                rawText: nil,
                metrics: VoiceMetrics(sttMs: sttMs, totalMs: totalMs)
            )
        }
        
        guard let systemPrompt = mode.systemPrompt else {
            let totalMs = Date().timeIntervalSince(totalStart) * 1000
            return VoiceResult(
                language: nil,
                text: rawText,
                rawText: nil,
                metrics: VoiceMetrics(sttMs: sttMs, totalMs: totalMs)
            )
        }
        
        let llmStart = Date()
        let finalPrompt = buildPrompt(systemPrompt: systemPrompt, context: context)
        let correctedText: String
        
        do {
            correctedText = try await processWithLLM(text: rawText, systemPrompt: finalPrompt)
        } catch {
            throw VoiceProviderError.llmFailed(error.localizedDescription)
        }
        
        let llmMs = Date().timeIntervalSince(llmStart) * 1000
        let totalMs = Date().timeIntervalSince(totalStart) * 1000
        
        return VoiceResult(
            language: nil,
            text: correctedText,
            rawText: rawText,
            metrics: VoiceMetrics(sttMs: sttMs, llmMs: llmMs, totalMs: totalMs)
        )
    }
    
    private func buildPrompt(systemPrompt: String, context: VoiceContext) -> String {
        var prompt = systemPrompt
        
        if !context.vocabulary.isEmpty {
            prompt += " Terms: \(context.vocabulary.joined(separator: ", "))"
        }
        
        return prompt
    }
    
    @MainActor
    private func processWithLLM(text: String, systemPrompt: String) async throws -> String {
        let llm = LLMService()
        return try await llm.process(text, systemPrompt: systemPrompt)
    }
}
