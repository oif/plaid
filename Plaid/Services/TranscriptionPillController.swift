import AppKit
import SwiftUI
import os.log

private let logger = Logger(subsystem: "com.neospaceindustries.plaid", category: "Pill")

class ClickablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

class TransparentHostingView<Content: View>: NSHostingView<Content> {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.backgroundColor = .clear
    }
    
    override var isOpaque: Bool { false }
}

@MainActor
class TranscriptionPillController {
    static let shared = TranscriptionPillController()
    
    private var panel: NSPanel?
    private var isShowing = false
    let pillState = TranscriptionPillState()
    private var textInjector: TextInjector?
    
    private init() {
        setupPanel()
    }
    
    func configure(textInjector: TextInjector) {
        self.textInjector = textInjector
        
        pillState.onComplete = { [weak self] text in
            self?.textInjector?.inject(text)
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
        let hostingView = TransparentHostingView(rootView: contentView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 280, height: 300)
        
        let panel = ClickablePanel(
            contentRect: hostingView.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        panel.contentView = hostingView
        
        self.panel = panel
    }
    
    func startRecording() {
        guard !isShowing else { return }
        guard let panel = panel else {
            logger.error("startRecording: panel is nil")
            return
        }
        
        let screen = activeScreen()
        isShowing = true
        pillState.show()
        
        let screenFrame = screen.visibleFrame
        let panelSize = panel.frame.size
        let x = screenFrame.midX - panelSize.width / 2
        let y = screenFrame.minY + 80
        
        panel.setFrameOrigin(NSPoint(x: x, y: y))
        panel.orderFrontRegardless()
        logger.info("startRecording: pill visible at (\(x), \(y))")
    }
    
    func stopRecording() {
        guard isShowing else { return }
        pillState.complete()
    }
    
    private func activeScreen() -> NSScreen {
        let mouseLocation = NSEvent.mouseLocation
        for screen in NSScreen.screens {
            if screen.frame.contains(mouseLocation) {
                return screen
            }
        }
        return NSScreen.main ?? NSScreen.screens.first!
    }
    
    func hide() {
        hidePanel()
        pillState.hide()
    }
    
    var isVisible: Bool {
        isShowing
    }
}
