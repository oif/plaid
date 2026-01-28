import AppKit
import Carbon
import OSLog
import ApplicationServices

private var _lastTriggerTime: UInt64 = 0
private var _hotkeyKeyCode: Int64 = 49
private var _hotkeyModifiers: CGEventFlags = []
private var _hotkeyUseFn: Bool = true

@MainActor
class GlobalHotkeyManager {
    static let shared = GlobalHotkeyManager()
    
    private let minIntervalNanoseconds: UInt64 = 300_000_000
    
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isStarted = false
    private var retryTimer: Timer?
    private var retryCount = 0
    private let maxRetries = 10
    
    var onHotkeyPressed: (() -> Void)?
    
    private init() {
        loadHotkeySettings()
        NotificationCenter.default.addObserver(
            forName: .hotkeyDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.loadHotkeySettings()
            Logger.hotkey.info("Hotkey settings changed - keyCode: \(_hotkeyKeyCode), useFn: \(_hotkeyUseFn)")
        }
    }
    
    private func loadHotkeySettings() {
        let settings = AppSettings.shared
        _hotkeyKeyCode = Int64(settings.hotkeyKeyCode)
        _hotkeyUseFn = settings.hotkeyUseFn
        
        var flags: CGEventFlags = []
        let mods = settings.hotkeyModifiers
        if mods & (1 << 0) != 0 { flags.insert(.maskCommand) }
        if mods & (1 << 1) != 0 { flags.insert(.maskShift) }
        if mods & (1 << 2) != 0 { flags.insert(.maskAlternate) }
        if mods & (1 << 3) != 0 { flags.insert(.maskControl) }
        _hotkeyModifiers = flags
    }
    
    nonisolated static func shouldTrigger() -> Bool {
        let now = mach_absolute_time()
        var timebase = mach_timebase_info_data_t()
        mach_timebase_info(&timebase)
        let nowNs = now * UInt64(timebase.numer) / UInt64(timebase.denom)
        
        if nowNs - _lastTriggerTime < 300_000_000 {
            return false
        }
        _lastTriggerTime = nowNs
        return true
    }
    
    // MARK: - Permission Check
    
    /// Check if accessibility permission is granted
    private func hasAccessibilityPermission() -> Bool {
        let trusted = AXIsProcessTrustedWithOptions([
            kAXTrustedCheckOptionPrompt.takeUnretainedValue(): false
        ] as CFDictionary)
        return trusted
    }
    
    /// Check system fn key setting for potential conflicts
    private func checkFnKeyConflict() -> Bool {
        guard _hotkeyUseFn else { return false }
        
        if let fnUsageType = UserDefaults.standard.persistentDomain(forName: "com.apple.HIToolbox")?["AppleFnUsageType"] as? Int {
            // 3 = Start Dictation, which conflicts with fn+key shortcuts
            if fnUsageType == 3 {
                Logger.hotkey.warning("System fn key is set to 'Start Dictation' - this may conflict with fn+Space hotkey")
                return true
            }
        }
        return false
    }
    
    // MARK: - Start/Stop
    
    func start() {
        guard !isStarted else {
            Logger.hotkey.debug("Event tap already started")
            return
        }
        
        Logger.hotkey.info("Starting global hotkey manager")
        
        // Check accessibility permission first
        guard hasAccessibilityPermission() else {
            Logger.hotkey.error("Cannot start event tap: Accessibility permission not granted")
            Task { @MainActor in
                DiagnosticsManager.shared.updateEventTapStatus(.permissionDenied, error: "Accessibility permission required")
            }
            startRetryTimer()
            return
        }
        
        // Check for fn key conflict
        if checkFnKeyConflict() {
            Logger.hotkey.warning("Potential fn key conflict detected - hotkey may not work as expected")
        }
        
        isStarted = true
        createEventTap()
    }
    
    private func createEventTap() {
        let eventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.flagsChanged.rawValue)
        
        let callback: CGEventTapCallBack = { proxy, type, event, refcon in
            guard let refcon = refcon else { return Unmanaged.passRetained(event) }
            let manager = Unmanaged<GlobalHotkeyManager>.fromOpaque(refcon).takeUnretainedValue()
            
            // CRITICAL: Handle tap being disabled by system
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                let reason = type == .tapDisabledByTimeout ? "timeout" : "user input"
                // Can't use Logger here (not async-safe), but we re-enable immediately
                if let tap = manager.eventTap {
                    CGEvent.tapEnable(tap: tap, enable: true)
                }
                // Schedule status update on main thread
                DispatchQueue.main.async {
                    Logger.hotkey.warning("Event tap was disabled by \(reason), re-enabled")
                    Task { @MainActor in
                        DiagnosticsManager.shared.updateEventTapStatus(.active)
                    }
                }
                return Unmanaged.passRetained(event)
            }
            
            let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) == 1
            if isRepeat {
                return Unmanaged.passRetained(event)
            }
            
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            let matchesKey = keyCode == _hotkeyKeyCode
            let matchesFn = !_hotkeyUseFn || event.flags.contains(.maskSecondaryFn)
            let matchesMods = _hotkeyModifiers.isEmpty || event.flags.contains(_hotkeyModifiers)
            let isHotkey = matchesKey && matchesFn && matchesMods
            
            if type == .keyDown && isHotkey {
                guard GlobalHotkeyManager.shouldTrigger() else {
                    DispatchQueue.main.async {
                        Logger.hotkey.debug("Hotkey debounced (too fast)")
                    }
                    return nil
                }
                DispatchQueue.main.async {
                    Logger.hotkey.info("Hotkey triggered, callback=\(manager.onHotkeyPressed != nil)")
                    manager.onHotkeyPressed?()
                }
                return nil
            }
            
            return Unmanaged.passRetained(event)
        }
        
        let refcon = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: callback,
            userInfo: refcon
        ) else {
            let hasPermission = hasAccessibilityPermission()
            let errorMsg = hasPermission 
                ? "CGEvent.tapCreate failed (unknown reason)"
                : "CGEvent.tapCreate failed (accessibility permission: \(hasPermission))"
            
            Logger.hotkey.error("\(errorMsg)")
            
            Task { @MainActor in
                DiagnosticsManager.shared.updateEventTapStatus(
                    hasPermission ? .failed : .permissionDenied,
                    error: errorMsg
                )
            }
            
            isStarted = false
            startRetryTimer()
            return
        }
        
        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        
        if let source = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            
            Logger.hotkey.info("Event tap created and enabled successfully")
            
            Task { @MainActor in
                DiagnosticsManager.shared.updateEventTapStatus(.active)
            }
            
            // Stop retry timer on success
            retryTimer?.invalidate()
            retryTimer = nil
            retryCount = 0
        }
    }
    
    private func startRetryTimer() {
        retryTimer?.invalidate()
        
        guard retryCount < maxRetries else {
            Logger.hotkey.error("Max retries (\(self.maxRetries)) reached for event tap creation")
            return
        }
        
        let interval = min(Double(retryCount + 1) * 2.0, 10.0) // Exponential backoff, max 10s
        Logger.hotkey.info("Will retry event tap creation in \(interval)s (attempt \(self.retryCount + 1)/\(self.maxRetries))")
        
        retryTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.retryCount += 1
                if self.hasAccessibilityPermission() && !self.isStarted {
                    self.isStarted = true
                    self.createEventTap()
                } else if !self.hasAccessibilityPermission() {
                    Logger.hotkey.debug("Still waiting for accessibility permission...")
                    self.startRetryTimer()
                }
            }
        }
    }
    
    func stop() {
        Logger.hotkey.info("Stopping global hotkey manager")
        
        retryTimer?.invalidate()
        retryTimer = nil
        
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        isStarted = false
        
        Task { @MainActor in
            DiagnosticsManager.shared.updateEventTapStatus(.disabled)
        }
    }
    
    /// Force restart the event tap (useful after permission changes)
    func restart() {
        Logger.hotkey.info("Restarting global hotkey manager")
        stop()
        retryCount = 0
        start()
    }
    
    // MARK: - Diagnostics
    
    /// Get current status for diagnostics
    var diagnosticStatus: String {
        var status = "Event Tap: \(isStarted ? "started" : "stopped")"
        status += "\nAccessibility: \(hasAccessibilityPermission() ? "granted" : "denied")"
        status += "\nHotkey: keyCode=\(_hotkeyKeyCode), useFn=\(_hotkeyUseFn)"
        if checkFnKeyConflict() {
            status += "\n⚠️ System fn key conflict detected"
        }
        return status
    }
}
