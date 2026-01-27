import Foundation

struct Mode: Identifiable, Codable, Hashable, Sendable {
    let id: String
    var name: String
    var icon: String
    var systemPrompt: String?
    var skipLLM: Bool
    var useSelectedText: Bool
    var isBuiltin: Bool
    
    init(
        id: String = UUID().uuidString,
        name: String,
        icon: String,
        systemPrompt: String?,
        skipLLM: Bool,
        useSelectedText: Bool = false,
        isBuiltin: Bool = false
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.systemPrompt = systemPrompt
        self.skipLLM = skipLLM
        self.useSelectedText = useSelectedText
        self.isBuiltin = isBuiltin
    }
    
    // MARK: - Built-in Modes
    
    static let voiceTranscription = Mode(
        id: "voice_transcription",
        name: "语音转录",
        icon: "🎤",
        systemPrompt: nil,
        skipLLM: true,
        useSelectedText: false,
        isBuiltin: true
    )
    
    static let dictation = Mode(
        id: "dictation",
        name: "听写纠错",
        icon: "✨",
        systemPrompt: "Fix transcription errors and filler words. Keep the original language and meaning. Output only the corrected text.",
        skipLLM: false,
        useSelectedText: false,
        isBuiltin: true
    )
    
    static let builtinModes: [Mode] = [.voiceTranscription, .dictation]
    
    static var defaultMode: Mode {
        let settings = AppSettings.shared
        if let mode = settings.mode(byId: settings.defaultModeId) {
            return mode
        }
        return .voiceTranscription
    }
    
    // MARK: - Hashable
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Mode, rhs: Mode) -> Bool {
        lhs.id == rhs.id
    }
}
