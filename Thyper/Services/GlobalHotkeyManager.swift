import AppKit
import Carbon

private var _lastTriggerTime: UInt64 = 0

@MainActor
class GlobalHotkeyManager {
    static let shared = GlobalHotkeyManager()
    
    private let minIntervalNanoseconds: UInt64 = 300_000_000
    
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isStarted = false
    
    var onHotkeyPressed: (() -> Void)?
    
    private init() {}
    
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
            let isFnSpace = keyCode == 49 && event.flags.contains(.maskSecondaryFn)
            
            if type == .keyDown && isFnSpace {
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
            print("⚠️ Failed to create event tap. Check accessibility permissions.")
            return
        }
        
        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        
        if let source = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            print("✅ Global hotkey manager started (fn+Space)")
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
