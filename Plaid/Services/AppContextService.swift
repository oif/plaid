import Foundation
import AppKit
import ApplicationServices

struct AppContext {
    let appName: String?
    let bundleId: String?
    let focusedElement: String?
    let windowTitle: String?
    let appCategory: String?
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
        var windowTitle: String?
        
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
            
            // Get focused window title from frontmost app
            if let pid = app?.processIdentifier {
                let appElement = AXUIElementCreateApplication(pid)
                var windowRef: CFTypeRef?
                if AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &windowRef) == .success,
                   let window = windowRef {
                    var titleRef: CFTypeRef?
                    if AXUIElementCopyAttributeValue(window as! AXUIElement, kAXTitleAttribute as CFString, &titleRef) == .success {
                        windowTitle = titleRef as? String
                        if windowTitle?.isEmpty == true { windowTitle = nil }
                    }
                }
            }
        }
        
        let bundleId = app?.bundleIdentifier
        let category = bundleId.flatMap { Self.appCategory(for: $0) }
        
        return AppContext(
            appName: app?.localizedName,
            bundleId: bundleId,
            focusedElement: focusedRole,
            windowTitle: windowTitle,
            appCategory: category
        )
    }
    
    // MARK: - App Category Mapping
    
    private static let categoryMap: [String: String] = [
        // Communication
        "com.tinyspeck.slackmacgap": "即时通讯",
        "com.apple.MobileSMS": "即时通讯",
        "ru.keepcoder.Telegram": "即时通讯",
        "com.electron.lark": "即时通讯",
        "com.tencent.xinWeChat": "即时通讯",
        "com.facebook.archon.developerID": "即时通讯",
        "us.zoom.xos": "视频会议",
        "com.microsoft.teams2": "视频会议",
        "com.google.Chrome.app.kjgfgldnnfobanck": "视频会议",
        // Email
        "com.apple.mail": "邮件",
        "com.microsoft.Outlook": "邮件",
        "com.google.Gmail": "邮件",
        // IDE / Code
        "com.microsoft.VSCode": "代码编辑器",
        "com.apple.dt.Xcode": "代码编辑器",
        "com.jetbrains.intellij": "代码编辑器",
        "com.sublimetext.4": "代码编辑器",
        "dev.zed.Zed": "代码编辑器",
        "com.googlecode.iterm2": "终端",
        "com.apple.Terminal": "终端",
        "net.kovidgoyal.kitty": "终端",
        "com.mitchellh.ghostty": "终端",
        // Writing / Notes
        "com.apple.Notes": "笔记",
        "md.obsidian": "笔记",
        "com.notion.Notion": "笔记",
        "com.apple.iWork.Pages": "文档编辑",
        "com.microsoft.Word": "文档编辑",
        "com.google.Chrome.app.Docs": "文档编辑",
        // Browser
        "com.apple.Safari": "浏览器",
        "com.google.Chrome": "浏览器",
        "org.mozilla.firefox": "浏览器",
        "com.microsoft.edgemac": "浏览器",
        "company.thebrowser.Browser": "浏览器",
        // Design
        "com.figma.Desktop": "设计工具",
        "com.bohemiancoding.sketch3": "设计工具",
        // Spreadsheet / Data
        "com.microsoft.Excel": "电子表格",
        "com.apple.iWork.Numbers": "电子表格",
        // Presentation
        "com.microsoft.Powerpoint": "演示文稿",
        "com.apple.iWork.Keynote": "演示文稿",
    ]
    
    private static func appCategory(for bundleId: String) -> String? {
        // Direct match
        if let category = categoryMap[bundleId] { return category }
        // Prefix match for JetBrains family etc.
        if bundleId.hasPrefix("com.jetbrains.") { return "代码编辑器" }
        return nil
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
