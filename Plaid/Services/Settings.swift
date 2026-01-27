import Foundation
import SwiftUI

class AppSettings: ObservableObject {
    static let shared = AppSettings()
    
    private let defaults = UserDefaults.standard
    
    // MARK: - STT Settings
    
    @Published var sttProvider: STTProvider {
        didSet { defaults.set(sttProvider.rawValue, forKey: "sttProvider") }
    }
    
    @Published var language: String {
        didSet { defaults.set(language, forKey: "language") }
    }
    
    // Custom STT endpoint (for Evernet or other services)
    @Published var customSTTEndpoint: String {
        didSet { defaults.set(customSTTEndpoint, forKey: "customSTTEndpoint") }
    }
    
    @Published var customSTTModel: String {
        didSet { defaults.set(customSTTModel, forKey: "customSTTModel") }
    }
    
    var customSTTApiKey: String {
        get { KeychainHelper.load(key: "custom_stt_key") ?? "" }
        set { KeychainHelper.save(key: "custom_stt_key", value: newValue) }
    }
    
    var elevenLabsApiKey: String {
        get { KeychainHelper.load(key: "elevenlabs_key") ?? "" }
        set { KeychainHelper.save(key: "elevenlabs_key", value: newValue) }
    }
    
    var sonioxApiKey: String {
        get { KeychainHelper.load(key: "soniox_key") ?? "" }
        set { KeychainHelper.save(key: "soniox_key", value: newValue) }
    }
    
    var glmApiKey: String {
        get { KeychainHelper.load(key: "glm_key") ?? "" }
        set { KeychainHelper.save(key: "glm_key", value: newValue) }
    }
    
    // MARK: - LLM Settings
    
    @Published var enableLLMCorrection: Bool {
        didSet { defaults.set(enableLLMCorrection, forKey: "enableLLMCorrection") }
    }
    
    @Published var llmProvider: LLMProvider {
        didSet { defaults.set(llmProvider.rawValue, forKey: "llmProvider") }
    }
    
    @Published var llmModel: String {
        didSet { defaults.set(llmModel, forKey: "llmModel") }
    }
    
    // Custom LLM endpoint (OpenAI compatible)
    @Published var customLLMEndpoint: String {
        didSet { defaults.set(customLLMEndpoint, forKey: "customLLMEndpoint") }
    }
    
    var openAIKey: String {
        get { KeychainHelper.load(key: "openai_key") ?? "" }
        set { KeychainHelper.save(key: "openai_key", value: newValue) }
    }
    
    var customLLMApiKey: String {
        get { KeychainHelper.load(key: "custom_llm_key") ?? "" }
        set { KeychainHelper.save(key: "custom_llm_key", value: newValue) }
    }
    
    // MARK: - General Settings
    
    @Published var autoInject: Bool {
        didSet { defaults.set(autoInject, forKey: "autoInject") }
    }
    
    @Published var customVocabulary: [String] {
        didSet { defaults.set(customVocabulary, forKey: "customVocabulary") }
    }
    
    // MARK: - Mode Settings
    
    @Published var customModes: [Mode] {
        didSet {
            if let data = try? JSONEncoder().encode(customModes) {
                defaults.set(data, forKey: "customModes")
            }
        }
    }
    
    @Published var lastSelectedModeId: String {
        didSet { defaults.set(lastSelectedModeId, forKey: "lastSelectedModeId") }
    }
    
    var allModes: [Mode] {
        Mode.builtinModes + customModes
    }
    
    func mode(byId id: String) -> Mode? {
        allModes.first { $0.id == id }
    }
    
    // MARK: - Initialization
    
    private init() {
        // STT
        let provider = defaults.string(forKey: "sttProvider") ?? "apple"
        self.sttProvider = STTProvider(rawValue: provider) ?? .appleSpeech
        self.language = defaults.string(forKey: "language") ?? "en-US"
        self.customSTTEndpoint = defaults.string(forKey: "customSTTEndpoint") ?? ""
        self.customSTTModel = defaults.string(forKey: "customSTTModel") ?? "whisper-1"
        
        // LLM
        self.enableLLMCorrection = defaults.object(forKey: "enableLLMCorrection") as? Bool ?? true
        let llmProv = defaults.string(forKey: "llmProvider") ?? "openai"
        self.llmProvider = LLMProvider(rawValue: llmProv) ?? .openAI
        self.llmModel = defaults.string(forKey: "llmModel") ?? "gpt-4o-mini"
        self.customLLMEndpoint = defaults.string(forKey: "customLLMEndpoint") ?? ""
        
        // General
        self.autoInject = defaults.object(forKey: "autoInject") as? Bool ?? true
        self.customVocabulary = defaults.stringArray(forKey: "customVocabulary") ?? []
        
        // Modes
        if let data = defaults.data(forKey: "customModes"),
           let modes = try? JSONDecoder().decode([Mode].self, from: data) {
            self.customModes = modes
        } else {
            self.customModes = []
        }
        self.lastSelectedModeId = defaults.string(forKey: "lastSelectedModeId") ?? Mode.defaultMode.id
    }
    
    // MARK: - Computed Properties
    
    var effectiveLLMEndpoint: String {
        switch llmProvider {
        case .openAI:
            return "https://api.openai.com/v1/chat/completions"
        case .custom:
            let base = customLLMEndpoint.trimmingCharacters(in: .whitespacesAndNewlines)
            if base.hasSuffix("/chat/completions") {
                return base
            } else if base.hasSuffix("/v1") {
                return base + "/chat/completions"
            } else if base.hasSuffix("/") {
                return base + "v1/chat/completions"
            } else {
                return base + "/v1/chat/completions"
            }
        }
    }
    
    var effectiveLLMApiKey: String {
        switch llmProvider {
        case .openAI:
            return openAIKey
        case .custom:
            return customLLMApiKey
        }
    }
    
    var effectiveSTTEndpoint: String {
        switch sttProvider {
        case .appleSpeech, .sherpaLocal:
            return ""
        case .whisperAPI:
            return "https://api.openai.com/v1/audio/transcriptions"
        case .elevenLabs:
            return "https://api.elevenlabs.io/v1/speech-to-text"
        case .soniox:
            return "https://api.soniox.com/v1"
        case .glmASR:
            return "https://open.bigmodel.cn/api/paas/v4/audio/transcriptions"
        case .customAPI:
            return customSTTEndpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
    
    var effectiveSTTApiKey: String {
        switch sttProvider {
        case .appleSpeech, .sherpaLocal:
            return ""
        case .whisperAPI:
            return openAIKey
        case .elevenLabs:
            return elevenLabsApiKey
        case .soniox:
            return sonioxApiKey
        case .glmASR:
            return glmApiKey
        case .customAPI:
            return customSTTApiKey
        }
    }
}

// MARK: - Enums

enum STTProvider: String, CaseIterable {
    case appleSpeech = "apple"
    case sherpaLocal = "sherpa"
    case whisperAPI = "whisper"
    case elevenLabs = "elevenlabs"
    case soniox = "soniox"
    case glmASR = "glm"
    case customAPI = "custom"
    
    var displayName: String {
        switch self {
        case .appleSpeech: return "Apple Speech"
        case .sherpaLocal: return "Local Model"
        case .whisperAPI: return "Whisper API"
        case .elevenLabs: return "ElevenLabs"
        case .soniox: return "Soniox"
        case .glmASR: return "GLM ASR"
        case .customAPI: return "Custom API"
        }
    }
    
    var icon: String {
        switch self {
        case .appleSpeech: return "apple.logo"
        case .sherpaLocal: return "cpu"
        case .whisperAPI: return "cloud.fill"
        case .elevenLabs: return "waveform.badge.mic"
        case .soniox: return "s.circle.fill"
        case .glmASR: return "g.circle.fill"
        case .customAPI: return "server.rack"
        }
    }
    
    var isLocal: Bool {
        switch self {
        case .appleSpeech, .sherpaLocal: return true
        default: return false
        }
    }
    
    var description: String {
        switch self {
        case .appleSpeech: return "Built-in macOS speech recognition"
        case .sherpaLocal: return "Fast, private, offline (SenseVoice, Whisper)"
        case .whisperAPI: return "OpenAI Whisper API"
        case .elevenLabs: return "ElevenLabs Scribe API"
        case .soniox: return "Soniox async transcription"
        case .glmASR: return "Zhipu GLM-ASR-2512 (CER 0.0717)"
        case .customAPI: return "Custom OpenAI-compatible endpoint"
        }
    }
}

enum LLMProvider: String, CaseIterable {
    case openAI = "openai"
    case custom = "custom"
    
    var displayName: String {
        switch self {
        case .openAI: return "OpenAI"
        case .custom: return "Custom"
        }
    }
    
    var icon: String {
        switch self {
        case .openAI: return "brain"
        case .custom: return "server.rack"
        }
    }
}

// MARK: - Network Session (with System Proxy)

enum NetworkSession {
    private static var _shared: URLSession?
    
    static var shared: URLSession {
        if let session = _shared {
            return session
        }
        
        let config = URLSessionConfiguration.default
        config.connectionProxyDictionary = CFNetworkCopySystemProxySettings()?.takeRetainedValue() as? [String: Any]
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 120
        
        let session = URLSession(configuration: config)
        _shared = session
        return session
    }
    
    static func reset() {
        _shared?.invalidateAndCancel()
        _shared = nil
    }
}

// MARK: - Keychain Helper

enum KeychainHelper {
    static func save(key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }
    
    static func load(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        
        return String(data: data, encoding: .utf8)
    }
}
