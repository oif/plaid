import Foundation
import SwiftUI

extension Notification.Name {
    static let hotkeyDidChange = Notification.Name("hotkeyDidChange")
}

@MainActor
class AppSettings: ObservableObject {
    static let shared = AppSettings()
    
    // MARK: - System Prompt (stable across requests, prompt-cache friendly)
    static let defaultSystemPrompt = """
你是语音转文字后处理助手。修正转录文本中的识别错误，输出干净的书面文本。仅输出修正结果，不要添加任何解释或前缀。

**修正规则（按优先级排序）：**
1. 自我纠正：说话人改口时，删除被否定的部分，只保留最终表述
   触发词：不对、不是、我说错了、等等应该是、哦不、我重新说
2. 同音字/谐音错误：当识别结果在语境中语义不通时，替换为发音相近且语义合理的字词（如「时间方式」在讨论方法论时应为「实践方式」；「以经」→「已经」）
3. 术语与品牌名：按官方拼写和大小写修正（cloudflare→Cloudflare, github→GitHub, iphone→iPhone）；保留英文术语原文，不要翻译为中文
4. 标点符号：添加或修正为正确的中/英文标点
5. 口语清理：移除填充词（嗯、啊、那个、就是说、然后然后）、无意义重复、不完整的句子碎片

**约束：**
- 保持说话人的语义、风格和意图不变
- 不要添加原文没有的信息
- 不要翻译——原文中英混合则保持混合
- 原文已正确时，原样输出

**关键词：**
"Plaid" 是本应用名称和唤醒词。发音接近 plaid/played/blade/plead/pled/plate/plain 且语义指代本应用时，修正为 "Plaid"。

**示例：**
输入：嗯那个我想把这个代码部署到cloudflare的workers上面然后然后用github action来自动化
输出：我想把这个代码部署到 Cloudflare 的 Workers 上面，然后用 GitHub Action 来自动化。

输入：他说这个modle的latancy太高了我们需要opitmize一下
输出：他说这个 model 的 latency 太高了，我们需要 optimize 一下。

输入：hey played帮我打开设置
输出：Hey Plaid，帮我打开设置。

输入：我们用那个react不对不是react用vue来写前端
输出：我们用 Vue 来写前端。

输入：这个项目大概需要三到不对是四到五天时间
输出：这个项目大概需要四到五天时间。

输入：我觉得这个方案OK没什么问题
输出：我觉得这个方案 OK，没什么问题。

输入：呃我可能会更加的关注是配置的一些时间方式不care部署的方式
输出：我可能会更加关注配置的一些实践方式，不 care 部署的方式。
"""
    
    // MARK: - User Prompt Template (dynamic per-request context)
    static let defaultUserPrompt = """
{{context}}
请修正以下转录文本：
{{text}}
"""
    
    // Legacy: combined prompt for migration
    static let defaultPrompt = defaultSystemPrompt + defaultUserPrompt
    
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
    
    @Published var customSystemPrompt: String {
        didSet { defaults.set(customSystemPrompt, forKey: "customSystemPrompt") }
    }
    
    @Published var customUserPrompt: String {
        didSet { defaults.set(customUserPrompt, forKey: "customUserPrompt") }
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
    
    @Published var enableDenoising: Bool {
        didSet { defaults.set(enableDenoising, forKey: "enableDenoising") }
    }
    
    @Published var customVocabulary: [String] {
        didSet { defaults.set(customVocabulary, forKey: "customVocabulary") }
    }
    
    // MARK: - Hotkey Settings
    
    @Published var hotkeyKeyCode: Int {
        didSet { 
            defaults.set(hotkeyKeyCode, forKey: "hotkeyKeyCode")
            NotificationCenter.default.post(name: .hotkeyDidChange, object: nil)
        }
    }
    
    @Published var hotkeyModifiers: Int {
        didSet { 
            defaults.set(hotkeyModifiers, forKey: "hotkeyModifiers")
            NotificationCenter.default.post(name: .hotkeyDidChange, object: nil)
        }
    }
    
    @Published var hotkeyUseFn: Bool {
        didSet { 
            defaults.set(hotkeyUseFn, forKey: "hotkeyUseFn")
            NotificationCenter.default.post(name: .hotkeyDidChange, object: nil)
        }
    }
    
    // MARK: - Initialization
    
    private init() {
        KeychainHelper.migrateIfNeeded()
        
        // STT
        let provider = defaults.string(forKey: "sttProvider") ?? "apple"
        self.sttProvider = STTProvider(rawValue: provider) ?? .appleSpeech
        self.language = defaults.string(forKey: "language") ?? "en-US"
        self.customSTTEndpoint = defaults.string(forKey: "customSTTEndpoint") ?? ""
        self.customSTTModel = defaults.string(forKey: "customSTTModel") ?? "whisper-1"
        
        // LLM
        self.enableLLMCorrection = defaults.object(forKey: "enableLLMCorrection") as? Bool ?? true
        
        // Migrate from legacy single customPrompt to split system/user prompts
        if let legacyPrompt = defaults.string(forKey: "customPrompt"),
           defaults.string(forKey: "customSystemPrompt") == nil {
            defaults.removeObject(forKey: "customPrompt")
            if legacyPrompt != AppSettings.defaultPrompt && !legacyPrompt.contains("{{text}}") {
                defaults.set(legacyPrompt, forKey: "customSystemPrompt")
            }
        }
        self.customSystemPrompt = defaults.string(forKey: "customSystemPrompt") ?? AppSettings.defaultSystemPrompt
        self.customUserPrompt = defaults.string(forKey: "customUserPrompt") ?? AppSettings.defaultUserPrompt
        let llmProv = defaults.string(forKey: "llmProvider") ?? "openai"
        self.llmProvider = LLMProvider(rawValue: llmProv) ?? .openAI
        self.llmModel = defaults.string(forKey: "llmModel") ?? "gpt-4o-mini"
        self.customLLMEndpoint = defaults.string(forKey: "customLLMEndpoint") ?? ""
        
        // General
        self.autoInject = defaults.object(forKey: "autoInject") as? Bool ?? true
        self.enableDenoising = defaults.object(forKey: "enableDenoising") as? Bool ?? true
        self.customVocabulary = defaults.stringArray(forKey: "customVocabulary") ?? []
        
        let spaceKeyCode = 49
        self.hotkeyKeyCode = defaults.object(forKey: "hotkeyKeyCode") as? Int ?? spaceKeyCode
        self.hotkeyModifiers = defaults.object(forKey: "hotkeyModifiers") as? Int ?? 0
        self.hotkeyUseFn = defaults.object(forKey: "hotkeyUseFn") as? Bool ?? true
    }
    
    // MARK: - Hotkey Display
    
    /// Returns the individual key parts for display (e.g. ["fn", "Space"] or ["⌘", "⇧", "R"])
    var hotkeyParts: [String] {
        var parts: [String] = []
        if hotkeyUseFn { parts.append("fn") }
        if hotkeyModifiers & (1 << 3) != 0 { parts.append("⌃") }
        if hotkeyModifiers & (1 << 2) != 0 { parts.append("⌥") }
        if hotkeyModifiers & (1 << 1) != 0 { parts.append("⇧") }
        if hotkeyModifiers & (1 << 0) != 0 { parts.append("⌘") }
        parts.append(Self.keyName(for: hotkeyKeyCode))
        return parts
    }
    
    /// Human-readable hotkey string (e.g. "fn Space", "⌘ ⇧ R")
    var hotkeyDisplayString: String {
        hotkeyParts.joined(separator: " ")
    }
    
    static func keyName(for code: Int) -> String {
        let keyNames: [Int: String] = [
            49: "Space", 36: "↩", 48: "⇥", 51: "⌫", 53: "Esc",
            123: "←", 124: "→", 125: "↓", 126: "↑",
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
            23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
            30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P",
            37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\",
            43: ",", 44: "/", 45: "N", 46: "M", 47: ".",
            122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
            98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12",
        ]
        return keyNames[code] ?? "Key \(code)"
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
    
    var subtitle: String {
        switch self {
        case .appleSpeech: return "Built-in macOS speech recognition"
        case .sherpaLocal: return "Fast, private, offline"
        case .whisperAPI: return "OpenAI cloud API"
        case .elevenLabs: return "ElevenLabs Scribe"
        case .soniox: return "Soniox transcription"
        case .glmASR: return "智谱 ASR"
        case .customAPI: return "OpenAI-compatible endpoint"
        }
    }
    
    var apiHint: String? {
        switch self {
        case .elevenLabs: return "Get key at elevenlabs.io"
        case .soniox: return "Get key at console.soniox.com"
        case .glmASR: return "Get key at open.bigmodel.cn"
        default: return nil
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
    private static let _shared: URLSession = {
        let config = URLSessionConfiguration.default
        config.connectionProxyDictionary = CFNetworkCopySystemProxySettings()?.takeRetainedValue() as? [String: Any]
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 120
        return URLSession(configuration: config)
    }()
    
    static var shared: URLSession { _shared }
}

// MARK: - Keychain Helper

enum KeychainHelper {
    private static let service = "com.neospaceindustries.plaid"
    
    static func save(key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }
        
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(deleteQuery as CFDictionary)
        
        guard !value.isEmpty else { return }
        
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        SecItemAdd(addQuery as CFDictionary, nil)
    }
    
    static func load(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
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
    
    static func migrateIfNeeded() {
        let migrated = UserDefaults.standard.bool(forKey: "keychain_migrated_v1")
        guard !migrated else { return }
        
        let keys = ["custom_stt_key", "elevenlabs_key", "soniox_key", "glm_key", "openai_key", "custom_llm_key"]
        for key in keys {
            let legacyQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: key,
                kSecReturnData as String: true,
                kSecMatchLimit as String: kSecMatchLimitOne
            ]
            var result: AnyObject?
            if SecItemCopyMatching(legacyQuery as CFDictionary, &result) == errSecSuccess,
               let data = result as? Data,
               let value = String(data: data, encoding: .utf8),
               !value.isEmpty {
                save(key: key, value: value)
                SecItemDelete(legacyQuery as CFDictionary)
            }
        }
        
        UserDefaults.standard.set(true, forKey: "keychain_migrated_v1")
    }
}
