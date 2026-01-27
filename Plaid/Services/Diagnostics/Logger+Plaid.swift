import OSLog

extension Logger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.neospaceindustries.plaid"
    
    // MARK: - Domain-specific Loggers
    
    /// General app lifecycle events
    static let app = Logger(subsystem: subsystem, category: "App")
    
    /// Global hotkey and event tap
    static let hotkey = Logger(subsystem: subsystem, category: "Hotkey")
    
    /// Audio pipeline, VAD, recording
    static let audio = Logger(subsystem: subsystem, category: "Audio")
    
    /// Speech-to-text processing
    static let stt = Logger(subsystem: subsystem, category: "STT")
    
    /// LLM correction
    static let llm = Logger(subsystem: subsystem, category: "LLM")
    
    /// System permissions (accessibility, microphone)
    static let permissions = Logger(subsystem: subsystem, category: "Permissions")
    
    /// Model downloading and management
    static let models = Logger(subsystem: subsystem, category: "Models")
    
    /// Text injection
    static let injection = Logger(subsystem: subsystem, category: "Injection")
    
    /// UI and views
    static let ui = Logger(subsystem: subsystem, category: "UI")
}
