import Foundation

struct VoiceMode: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let name: String
    let systemPrompt: String?
    let skipLLM: Bool
    
    init(id: String, name: String, systemPrompt: String?, skipLLM: Bool) {
        self.id = id
        self.name = name
        self.systemPrompt = systemPrompt
        self.skipLLM = skipLLM
    }
    
    // MARK: - Built-in Modes
    
    static let transcribe = VoiceMode(
        id: "transcribe",
        name: "Transcribe",
        systemPrompt: nil,
        skipLLM: true
    )
    
    static let dictation = VoiceMode(
        id: "dictation",
        name: "Dictation",
        systemPrompt: "Fix transcription errors and filler words. Keep the original language and meaning. Output only the corrected text.",
        skipLLM: false
    )
    
    static let jarvis = VoiceMode(
        id: "jarvis",
        name: "Jarvis",
        systemPrompt: "You are Jarvis, an AI assistant. The user will give you voice commands. Execute the command and respond appropriately. Be concise and direct.",
        skipLLM: false
    )
    
    static let builtinModes: [VoiceMode] = [.transcribe, .dictation, .jarvis]
    
    // MARK: - Hashable
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: VoiceMode, rhs: VoiceMode) -> Bool {
        lhs.id == rhs.id
    }
}
