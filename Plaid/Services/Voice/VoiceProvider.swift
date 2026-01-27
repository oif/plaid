import Foundation

protocol VoiceProvider: Sendable {
    var name: String { get }
    var isLocal: Bool { get }
    
    func process(
        audio: ProcessedAudio,
        context: VoiceContext,
        mode: VoiceMode
    ) async throws -> VoiceResult
}

enum VoiceProviderError: Error, LocalizedError {
    case notInitialized
    case transcriptionFailed(String)
    case llmFailed(String)
    case cancelled
    
    var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "Voice provider not initialized"
        case .transcriptionFailed(let reason):
            return "Transcription failed: \(reason)"
        case .llmFailed(let reason):
            return "LLM correction failed: \(reason)"
        case .cancelled:
            return "Operation cancelled"
        }
    }
}
