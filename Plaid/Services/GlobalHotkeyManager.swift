import AppKit
import Carbon
import OSLog
import ApplicationServices

// MARK: - Gesture State Machine (file-level for CGEvent tap callback)

private enum GestureState {
    case idle
    case holdPending
    case waitSecondTap
    case holdActive
    case toggleRecording
    case toggleStopping
}

private var _gestureState: GestureState = .idle
private var _gestureTimer: DispatchWorkItem?
private var _gestureKeyCode: Int64 = 63

private let _modifierKeyFlags: [Int64: CGEventFlags] = [
    63: .maskSecondaryFn,
    58: .maskAlternate, 61: .maskAlternate,
    59: .maskControl, 62: .maskControl,
    55: .maskCommand, 54: .maskCommand,
    56: .maskShift, 60: .maskShift,
]

private let _gestureThresholdMs = 300

@MainActor
class GlobalHotkeyManager {
    static let shared = GlobalHotkeyManager()
    
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isStarted = false
    private var retryTimer: Timer?
    private var retryCount = 0
    private let maxRetries = 10
    
    var onHoldStart: (() -> Void)?
    var onHoldEnd: (() -> Void)?
    var onToggleStart: (() -> Void)?
    var onToggleStop: (() -> Void)?
    
    private init() {
        loadSettings()
        NotificationCenter.default.addObserver(
            forName: .hotkeyDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.loadSettings()
            Logger.hotkey.info("Gesture key changed to keyCode: \(_gestureKeyCode)")
        }
    }
    
    private func loadSettings() {
        _gestureKeyCode = Int64(AppSettings.shared.holdKeyCode)
    }
    
    // MARK: - Permission Check
    
    private func hasAccessibilityPermission() -> Bool {
        let trusted = AXIsProcessTrustedWithOptions([
            kAXTrustedCheckOptionPrompt.takeUnretainedValue(): false
        ] as CFDictionary)
        return trusted
    }
    
    private func checkFnKeyConflict() -> Bool {
        guard _gestureKeyCode == 63 else { return false }
        
        if let fnUsageType = UserDefaults.standard.persistentDomain(forName: "com.apple.HIToolbox")?["AppleFnUsageType"] as? Int {
            if fnUsageType == 3 {
                Logger.hotkey.warning("System fn key is set to 'Start Dictation' - this may conflict with gesture key")
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
        
        guard hasAccessibilityPermission() else {
            Logger.hotkey.error("Cannot start event tap: Accessibility permission not granted")
            Task { @MainActor in
                DiagnosticsManager.shared.updateEventTapStatus(.permissionDenied, error: "Accessibility permission required")
            }
            startRetryTimer()
            return
        }
        
        if checkFnKeyConflict() {
            Logger.hotkey.warning("Potential fn key conflict detected")
        }
        
        isStarted = true
        createEventTap()
    }
    
    private func createEventTap() {
        let eventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue) | (1 << CGEventType.flagsChanged.rawValue)
        
        let callback: CGEventTapCallBack = { proxy, type, event, refcon in
            guard let refcon = refcon else { return Unmanaged.passRetained(event) }
            let manager = Unmanaged<GlobalHotkeyManager>.fromOpaque(refcon).takeUnretainedValue()
            
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let tap = manager.eventTap {
                    CGEvent.tapEnable(tap: tap, enable: true)
                }
                DispatchQueue.main.async {
                    Logger.hotkey.warning("Event tap re-enabled after \(type == .tapDisabledByTimeout ? "timeout" : "user input")")
                    Task { @MainActor in
                        DiagnosticsManager.shared.updateEventTapStatus(.active)
                    }
                }
                return Unmanaged.passRetained(event)
            }
            
            let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) == 1
            if isRepeat { return Unmanaged.passRetained(event) }
            
            let eventKeyCode = event.getIntegerValueField(.keyboardEventKeycode)
            let isModifierGesture = _modifierKeyFlags[_gestureKeyCode] != nil
            
            if isModifierGesture {
                guard let gestureFlag = _modifierKeyFlags[_gestureKeyCode] else {
                    return Unmanaged.passRetained(event)
                }
                
                if type == .flagsChanged && eventKeyCode == _gestureKeyCode {
                    let isPressed = event.flags.contains(gestureFlag)
                    
                    switch _gestureState {
                    case .idle:
                        if isPressed {
                            _gestureState = .holdPending
                            _gestureTimer?.cancel()
                            let timer = DispatchWorkItem {
                                guard _gestureState == .holdPending else { return }
                                _gestureState = .holdActive
                                DispatchQueue.main.async {
                                    Logger.hotkey.info("Hold started")
                                    manager.onHoldStart?()
                                }
                            }
                            _gestureTimer = timer
                            DispatchQueue.global().asyncAfter(
                                deadline: .now() + .milliseconds(_gestureThresholdMs),
                                execute: timer
                            )
                        }
                        
                    case .holdPending:
                        if !isPressed {
                            _gestureTimer?.cancel()
                            _gestureState = .waitSecondTap
                            let timer = DispatchWorkItem {
                                guard _gestureState == .waitSecondTap else { return }
                                _gestureState = .idle
                            }
                            _gestureTimer = timer
                            DispatchQueue.global().asyncAfter(
                                deadline: .now() + .milliseconds(_gestureThresholdMs),
                                execute: timer
                            )
                        }
                        
                    case .waitSecondTap:
                        if isPressed {
                            _gestureTimer?.cancel()
                            _gestureState = .toggleRecording
                            DispatchQueue.main.async {
                                Logger.hotkey.info("Double-tap → toggle start")
                                manager.onToggleStart?()
                            }
                        }
                        
                    case .holdActive:
                        if !isPressed {
                            _gestureState = .idle
                            DispatchQueue.main.async {
                                Logger.hotkey.info("Hold ended")
                                manager.onHoldEnd?()
                            }
                        }
                        
                    case .toggleRecording:
                        if isPressed {
                            _gestureState = .toggleStopping
                            DispatchQueue.main.async {
                                Logger.hotkey.info("Single-tap → toggle stop")
                                manager.onToggleStop?()
                            }
                        }
                        
                    case .toggleStopping:
                        if !isPressed {
                            _gestureState = .idle
                        }
                    }
                    
                    return Unmanaged.passRetained(event)
                }
                
                if type == .keyDown && (_gestureState == .holdPending || _gestureState == .waitSecondTap) {
                    _gestureTimer?.cancel()
                    _gestureState = .idle
                }
                
            } else {
                let isGestureKey = eventKeyCode == _gestureKeyCode
                
                if isGestureKey {
                    switch _gestureState {
                    case .idle:
                        if type == .keyDown {
                            _gestureState = .holdPending
                            _gestureTimer?.cancel()
                            let timer = DispatchWorkItem {
                                guard _gestureState == .holdPending else { return }
                                _gestureState = .holdActive
                                DispatchQueue.main.async {
                                    Logger.hotkey.info("Hold started")
                                    manager.onHoldStart?()
                                }
                            }
                            _gestureTimer = timer
                            DispatchQueue.global().asyncAfter(
                                deadline: .now() + .milliseconds(_gestureThresholdMs),
                                execute: timer
                            )
                            return nil
                        }
                        
                    case .holdPending:
                        if type == .keyUp {
                            _gestureTimer?.cancel()
                            _gestureState = .waitSecondTap
                            let timer = DispatchWorkItem {
                                guard _gestureState == .waitSecondTap else { return }
                                _gestureState = .idle
                            }
                            _gestureTimer = timer
                            DispatchQueue.global().asyncAfter(
                                deadline: .now() + .milliseconds(_gestureThresholdMs),
                                execute: timer
                            )
                            return nil
                        }
                        
                    case .waitSecondTap:
                        if type == .keyDown {
                            _gestureTimer?.cancel()
                            _gestureState = .toggleRecording
                            DispatchQueue.main.async {
                                Logger.hotkey.info("Double-tap → toggle start")
                                manager.onToggleStart?()
                            }
                            return nil
                        }
                        
                    case .holdActive:
                        if type == .keyUp {
                            _gestureState = .idle
                            DispatchQueue.main.async {
                                Logger.hotkey.info("Hold ended")
                                manager.onHoldEnd?()
                            }
                            return nil
                        }
                        
                    case .toggleRecording:
                        if type == .keyDown {
                            _gestureState = .toggleStopping
                            DispatchQueue.main.async {
                                Logger.hotkey.info("Single-tap → toggle stop")
                                manager.onToggleStop?()
                            }
                            return nil
                        }
                        
                    case .toggleStopping:
                        if type == .keyUp {
                            _gestureState = .idle
                            return nil
                        }
                    }
                }
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
        
        let interval = min(Double(retryCount + 1) * 2.0, 10.0)
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
    
    func restart() {
        Logger.hotkey.info("Restarting global hotkey manager")
        stop()
        retryCount = 0
        start()
    }
    
    // MARK: - Diagnostics
    
    var diagnosticStatus: String {
        var status = "Event Tap: \(isStarted ? "started" : "stopped")"
        status += "\nAccessibility: \(hasAccessibilityPermission() ? "granted" : "denied")"
        status += "\nGesture Key: keyCode=\(_gestureKeyCode)"
        if checkFnKeyConflict() {
            status += "\n⚠️ System fn key conflict detected"
        }
        return status
    }
}
