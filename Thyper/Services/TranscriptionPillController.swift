import AppKit
import SwiftUI
import os.log

private let logger = Logger(subsystem: "com.thyper", category: "PillController")

class ClickablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
class TranscriptionPillController {
    static let shared = TranscriptionPillController()
    
    private var panel: NSPanel?
    private var isShowing = false
    let pillState = TranscriptionPillState()
    
    private init() {
        setupPanel()
    }
    
    func configure(sttService: STTService, llmService: LLMService, textInjector: TextInjector) {
        pillState.configure(sttService: sttService, llmService: llmService)
        
        pillState.onComplete = { [weak self] text in
            textInjector.inject(text)
            self?.hide()
        }
        
        pillState.onCancel = { [weak self] in
            self?.hide()
        }
        
        pillState.onHide = { [weak self] in
            self?.hidePanel()
        }
    }
    
    private func hidePanel() {
        guard isShowing else { return }
        isShowing = false
        panel?.orderOut(nil)
    }
    
    private func setupPanel() {
        let contentView = TranscriptionPillView(pillState: pillState)
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 120, height: 36)
        hostingView.focusRingType = .none
        
        let panel = ClickablePanel(
            contentRect: hostingView.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        panel.contentView = hostingView
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        
        self.panel = panel
    }
    
    private func log(_ msg: String) {
        let str = "\(Date()): [Pill] \(msg)\n"
        let url = URL(fileURLWithPath: "/Users/neo/Desktop/thyper_debug.log")
        if let data = str.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: url.path) {
                if let handle = try? FileHandle(forWritingTo: url) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    try? handle.close()
                }
            } else {
                try? data.write(to: url)
            }
        }
    }
    
    func toggle() {
        log("toggle() isShowing=\(isShowing)")
        if isShowing {
            pillState.toggle()
        } else {
            show()
        }
    }
    
    func show() {
        log("show() isShowing=\(isShowing)")
        guard !isShowing else {
            log("Already showing, skip")
            return
        }
        guard let panel = panel, let screen = NSScreen.main else { return }
        
        isShowing = true
        
        let screenFrame = screen.visibleFrame
        let panelSize = panel.frame.size
        let x = screenFrame.midX - panelSize.width / 2
        let y = screenFrame.minY + 80
        
        panel.setFrameOrigin(NSPoint(x: x, y: y))
        panel.orderFrontRegardless()
        
        pillState.show()
    }
    
    func hide() {
        hidePanel()
        pillState.hide()
    }
    
    var isVisible: Bool {
        isShowing
    }
}
