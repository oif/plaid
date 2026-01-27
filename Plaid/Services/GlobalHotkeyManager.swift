import AppKit
import Carbon

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
    
    var onHotkeyPressed: (() -> Void)?
    
    private init() {
        loadHotkeySettings()
        NotificationCenter.default.addObserver(
            forName: .hotkeyDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.loadHotkeySettings()
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
    
    func start() {
        guard !isStarted else { return }
        isStarted = true
        
        let eventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.flagsChanged.rawValue)
        
        let callback: CGEventTapCallBack = { proxy, type, event, refcon in
            guard let refcon = refcon else { return Unmanaged.passRetained(event) }
            let manager = Unmanaged<GlobalHotkeyManager>.fromOpaque(refcon).takeUnretainedValue()
            
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let tap = manager.eventTap {
                    CGEvent.tapEnable(tap: tap, enable: true)
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
                    return nil
                }
                DispatchQueue.main.async {
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
            return
        }
        
        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        
        if let source = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
        }
    }
    
    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        isStarted = false
    }
    
}
