import Foundation
import OSLog
import OSLogClient
import ApplicationServices
import AppKit

/// Centralized diagnostics manager for Plaid
/// Handles logging initialization, permission monitoring, and diagnostic exports
@MainActor
final class DiagnosticsManager: ObservableObject {
    static let shared = DiagnosticsManager()
    
    // MARK: - Published State
    
    @Published private(set) var isAccessibilityGranted = false
    @Published private(set) var isMicrophoneGranted = false
    @Published private(set) var eventTapStatus: EventTapStatus = .unknown
    @Published private(set) var lastEventTapError: String?
    
    // MARK: - Private Properties
    
    private var permissionTimer: Timer?
    private var logDriver: FileLogDriver?
    
    private let logFileURL: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let plaidDir = appSupport.appendingPathComponent("Plaid", isDirectory: true)
        try? FileManager.default.createDirectory(at: plaidDir, withIntermediateDirectories: true)
        return plaidDir.appendingPathComponent("plaid.log")
    }()
    
    // MARK: - Types
    
    enum EventTapStatus: String {
        case unknown = "Unknown"
        case active = "Active"
        case failed = "Failed"
        case permissionDenied = "Permission Denied"
        case disabled = "Disabled"
    }
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Initialize the diagnostics system
    func initialize() async {
        Logger.app.info("Initializing diagnostics system")
        
        // Initialize OSLogClient for log collection
        do {
            try await OSLogClient.initialize(pollingInterval: .medium)
            
            // Register file log driver
            logDriver = FileLogDriver(
                id: "plaid-file-driver",
                logFileUrl: logFileURL,
                logFilters: [.subsystem(Bundle.main.bundleIdentifier ?? "com.neospaceindustries.plaid")]
            )
            
            if let driver = logDriver {
                await OSLogClient.registerDriver(driver)
            }
            
            await OSLogClient.startPolling()
            Logger.app.info("OSLogClient initialized successfully")
        } catch {
            Logger.app.error("Failed to initialize OSLogClient: \(error.localizedDescription)")
        }
        
        // Check initial permissions
        checkPermissions()
        
        // Start permission monitoring
        startPermissionMonitoring()
    }
    
    /// Check all permissions
    func checkPermissions() {
        // Accessibility
        let accessibilityGranted = AXIsProcessTrustedWithOptions([
            kAXTrustedCheckOptionPrompt.takeUnretainedValue(): false
        ] as CFDictionary)
        
        if accessibilityGranted != isAccessibilityGranted {
            isAccessibilityGranted = accessibilityGranted
            Logger.permissions.info("Accessibility permission: \(accessibilityGranted ? "granted" : "denied")")
        }
        
        // Microphone - check via AVCaptureDevice would require importing AVFoundation
        // For now, we'll track it when audio starts
    }
    
    /// Request accessibility permission
    func requestAccessibilityPermission() {
        Logger.permissions.info("Requesting accessibility permission")
        
        // Trigger system prompt
        AXIsProcessTrustedWithOptions([
            kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true
        ] as CFDictionary)
        
        // Open System Settings
        openAccessibilitySettings()
    }
    
    /// Open System Settings to Accessibility pane
    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
    
    /// Open System Settings to Microphone pane
    func openMicrophoneSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
    }
    
    /// Update event tap status
    func updateEventTapStatus(_ status: EventTapStatus, error: String? = nil) {
        eventTapStatus = status
        lastEventTapError = error
        
        switch status {
        case .active:
            Logger.hotkey.info("Event tap is active")
        case .failed:
            Logger.hotkey.error("Event tap failed: \(error ?? "unknown")")
        case .permissionDenied:
            Logger.hotkey.warning("Event tap permission denied")
        case .disabled:
            Logger.hotkey.warning("Event tap disabled by system")
        case .unknown:
            break
        }
    }
    
    /// Export diagnostics as a string
    func exportDiagnostics() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
        
        var report = """
        ==========================================
        PLAID DIAGNOSTICS REPORT
        Generated: \(dateFormatter.string(from: Date()))
        ==========================================
        
        === APP INFO ===
        Version: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown")
        Build: \(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown")
        Bundle ID: \(Bundle.main.bundleIdentifier ?? "unknown")
        
        === SYSTEM INFO ===
        macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)
        
        === PERMISSIONS ===
        Accessibility: \(isAccessibilityGranted ? "GRANTED" : "DENIED")
        Microphone: \(isMicrophoneGranted ? "GRANTED" : "UNKNOWN")
        
        === EVENT TAP ===
        Status: \(eventTapStatus.rawValue)
        Last Error: \(lastEventTapError ?? "none")
        
        === HOTKEY CONFIG ===
        KeyCode: \(AppSettings.shared.hotkeyKeyCode)
        Use Fn: \(AppSettings.shared.hotkeyUseFn)
        Modifiers: \(AppSettings.shared.hotkeyModifiers)
        
        === FN KEY SYSTEM SETTING ===
        """
        
        // Check fn key system setting
        if let fnUsageType = UserDefaults.standard.persistentDomain(forName: "com.apple.HIToolbox")?["AppleFnUsageType"] as? Int {
            let fnUsageDescription: String
            switch fnUsageType {
            case 0: fnUsageDescription = "Do Nothing"
            case 1: fnUsageDescription = "Change Input Source"
            case 2: fnUsageDescription = "Show Emoji & Symbols"
            case 3: fnUsageDescription = "Start Dictation (CONFLICTS WITH PLAID!)"
            default: fnUsageDescription = "Unknown (\(fnUsageType))"
            }
            report += "\nFn Key Usage: \(fnUsageDescription)"
        } else {
            report += "\nFn Key Usage: Could not determine"
        }
        
        // Add recent logs
        report += "\n\n=== RECENT LOGS ===\n"
        if let logContents = try? String(contentsOf: logFileURL, encoding: .utf8) {
            let lines = logContents.components(separatedBy: .newlines)
            let recentLines = lines.suffix(100)
            report += recentLines.joined(separator: "\n")
        } else {
            report += "(No logs available)"
        }
        
        return report
    }
    
    /// Get log file URL for sharing
    func getLogFileURL() -> URL {
        return logFileURL
    }
    
    /// Clear log file
    func clearLogs() {
        try? "".write(to: logFileURL, atomically: true, encoding: .utf8)
        Logger.app.info("Logs cleared")
    }
    
    // MARK: - Private Methods
    
    private func startPermissionMonitoring() {
        permissionTimer?.invalidate()
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkPermissions()
            }
        }
    }
}

// MARK: - FileLogDriver

/// Custom log driver that writes logs to a file
final class FileLogDriver: LogDriver, @unchecked Sendable {
    
    private let logFileUrl: URL
    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return f
    }()
    
    init(id: String, logFileUrl: URL, logFilters: Set<LogFilter> = []) {
        self.logFileUrl = logFileUrl
        super.init(id: id, logFilters: logFilters)
    }
    
    required init(id: String, logFilters: Set<LogFilter> = []) {
        fatalError("init(id:logFilters:) has not been implemented - use init(id:logFileUrl:logFilters:)")
    }
    
    #if os(macOS)
    override func processLog(level: LogDriver.LogLevel, subsystem: String, category: String, date: Date, message: String, components: [OSLogMessageComponent]) {
        writeLog(level: level, category: category, date: date, message: message)
    }
    #else
    override func processLog(level: LogDriver.LogLevel, subsystem: String, category: String, date: Date, message: String) {
        writeLog(level: level, category: category, date: date, message: message)
    }
    #endif
    
    private func writeLog(level: LogLevel, category: String, date: Date, message: String) {
        let levelStr: String
        switch level {
        case .debug: levelStr = "DEBUG"
        case .info: levelStr = "INFO"
        case .notice: levelStr = "NOTICE"
        case .error: levelStr = "ERROR"
        case .fault: levelStr = "FAULT"
        case .undefined: levelStr = "LOG"
        @unknown default: levelStr = "LOG"
        }
        
        let formattedMessage = "[\(dateFormatter.string(from: date))] [\(levelStr)] [\(category)] \(message)\n"
        
        // Append to file
        if let data = formattedMessage.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logFileUrl.path) {
                if let fileHandle = try? FileHandle(forWritingTo: logFileUrl) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                }
            } else {
                try? data.write(to: logFileUrl)
            }
        }
    }
}
