import Foundation
import AppKit
import CoreGraphics

class TextInjector {
    func inject(_ text: String) {
        guard AXIsProcessTrusted() else {
            print("Accessibility permission required")
            return
        }
        
        injectViaKeyboard(text)
    }
    
    private func injectViaKeyboard(_ text: String) {
        let source = CGEventSource(stateID: .hidSystemState)
        let utf16 = Array(text.utf16)
        
        let chunkSize = 20
        var offset = 0
        
        while offset < utf16.count {
            let end = min(offset + chunkSize, utf16.count)
            var chunk = Array(utf16[offset..<end])
            
            guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
                  let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else {
                return
            }
            
            keyDown.keyboardSetUnicodeString(stringLength: chunk.count, unicodeString: &chunk)
            keyUp.keyboardSetUnicodeString(stringLength: chunk.count, unicodeString: &chunk)
            
            keyDown.post(tap: .cghidEventTap)
            keyUp.post(tap: .cghidEventTap)
            
            offset = end
            usleep(5000)
        }
    }
    
    func injectViaClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        let previous = pasteboard.string(forType: .string)
        
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        
        simulatePaste()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            pasteboard.clearContents()
            if let prev = previous {
                pasteboard.setString(prev, forType: .string)
            }
        }
    }
    
    private func simulatePaste() {
        let source = CGEventSource(stateID: .hidSystemState)
        
        guard let vDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true),
              let vUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false) else {
            return
        }
        
        vDown.flags = .maskCommand
        vUp.flags = .maskCommand
        
        vDown.post(tap: .cghidEventTap)
        usleep(1000)
        vUp.post(tap: .cghidEventTap)
    }
}
