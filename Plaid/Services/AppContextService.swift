import Foundation
import AppKit
import ApplicationServices

struct AppContext {
    let appName: String?
    let bundleId: String?
    let focusedElement: String?
}

class AppContextService: ObservableObject {
    @Published var currentAppName: String?
    @Published var hasAccessibilityPermission = false
    
    init() {
        checkAccessibilityPermission()
    }
    
    func checkAccessibilityPermission() {
        hasAccessibilityPermission = AXIsProcessTrusted()
    }
    
    func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }
    
    func updateCurrentApp() {
        if let app = NSWorkspace.shared.frontmostApplication {
            currentAppName = app.localizedName
        }
    }
    
    func getCurrentContext() -> AppContext {
        let app = NSWorkspace.shared.frontmostApplication
        
        var focusedRole: String?
        if hasAccessibilityPermission {
            let systemWide = AXUIElementCreateSystemWide()
            var focusedRef: CFTypeRef?
            
            if AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focusedRef) == .success,
               let ref = focusedRef {
                let element = ref as! AXUIElement
                var roleRef: CFTypeRef?
                if AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef) == .success {
                    focusedRole = roleRef as? String
                }
            }
        }
        
        return AppContext(
            appName: app?.localizedName,
            bundleId: app?.bundleIdentifier,
            focusedElement: focusedRole
        )
    }
    
    @MainActor
    func getVoiceContext() -> VoiceContext {
        let app = NSWorkspace.shared.frontmostApplication
        let settings = AppSettings.shared
        
        return VoiceContext(
            appName: app?.localizedName,
            bundleId: app?.bundleIdentifier,
            documentType: nil,
            recentText: nil,
            vocabulary: settings.customVocabulary
        )
    }
    
    func getSelectedText() -> String? {
        guard hasAccessibilityPermission else { return nil }
        
        let systemWide = AXUIElementCreateSystemWide()
        var focusedRef: CFTypeRef?
        
        guard AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedRef
        ) == .success else {
            return nil
        }
        
        guard let element = focusedRef else { return nil }
        var selectedTextRef: CFTypeRef?
        
        guard AXUIElementCopyAttributeValue(
            element as! AXUIElement,
            kAXSelectedTextAttribute as CFString,
            &selectedTextRef
        ) == .success else {
            return nil
        }
        
        let text = selectedTextRef as? String
        return text?.isEmpty == true ? nil : text
    }
}
