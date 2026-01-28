import SwiftUI

struct SettingsContentView: View {
    let selectedSection: SettingsSection
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var modelManager: ModelManager
    @EnvironmentObject var audioInputManager: AudioInputManager
    
    @State private var apiKey = ""
    @State private var customSTTApiKey = ""
    @State private var customLLMApiKey = ""
    @State private var elevenLabsApiKey = ""
    @State private var sonioxApiKey = ""
    @State private var glmApiKey = ""
    @State private var plaidCloudApiKey = ""
    
    var body: some View {
        Group {
            switch selectedSection {
            case .general:
                generalTab
            case .speech:
                speechTab
            case .vocabulary:
                vocabularyTab
            case .integrations:
                integrationsTab
            case .diagnostics:
                diagnosticsTab
            case .about:
                aboutTab
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            apiKey = settings.openAIKey
            customSTTApiKey = settings.customSTTApiKey
            customLLMApiKey = settings.customLLMApiKey
            elevenLabsApiKey = settings.elevenLabsApiKey
            sonioxApiKey = settings.sonioxApiKey
            glmApiKey = settings.glmApiKey
            plaidCloudApiKey = settings.plaidCloudApiKey
        }
    }
    
    private var generalTab: some View {
        GeneralSettingsView()
    }
    
    private var speechTab: some View {
        SpeechSettingsView(
            apiKey: $apiKey,
            customSTTApiKey: $customSTTApiKey,
            customLLMApiKey: $customLLMApiKey,
            elevenLabsApiKey: $elevenLabsApiKey,
            sonioxApiKey: $sonioxApiKey,
            glmApiKey: $glmApiKey,
            plaidCloudApiKey: $plaidCloudApiKey
        )
    }
    
    private var vocabularyTab: some View {
        VocabularySettingsView()
    }
    
    private var integrationsTab: some View {
        IntegrationsSettingsView()
    }
    
    private var aboutTab: some View {
        AboutSettingsView()
    }
    
    private var diagnosticsTab: some View {
        DiagnosticsSettingsView()
    }
}

struct HotkeyRecorder: View {
    @Binding var keyCode: Int
    @Binding var modifiers: Int
    @Binding var useFn: Bool
    
    @State private var isRecording = false
    @State private var eventMonitor: Any?
    
    var body: some View {
        Button {
            if isRecording {
                stopRecording()
            } else {
                startRecording()
            }
        } label: {
            HStack(spacing: 4) {
                Text(displayString)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                if isRecording {
                    Image(systemName: "keyboard")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(isRecording ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.1))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(isRecording ? Color.accentColor : Color.clear, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .onDisappear { stopRecording() }
    }
    
    private func startRecording() {
        isRecording = true
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 {
                stopRecording()
                return nil
            }
            
            keyCode = Int(event.keyCode)
            
            var mods = 0
            if event.modifierFlags.contains(.command) { mods |= (1 << 0) }
            if event.modifierFlags.contains(.shift) { mods |= (1 << 1) }
            if event.modifierFlags.contains(.option) { mods |= (1 << 2) }
            if event.modifierFlags.contains(.control) { mods |= (1 << 3) }
            modifiers = mods
            
            useFn = event.modifierFlags.contains(.function)
            
            stopRecording()
            return nil
        }
    }
    
    private func stopRecording() {
        isRecording = false
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
    
    private var displayString: String {
        if isRecording { return "Recording..." }
        
        var parts: [String] = []
        
        if useFn { parts.append("fn") }
        if modifiers & (1 << 3) != 0 { parts.append("⌃") }
        if modifiers & (1 << 2) != 0 { parts.append("⌥") }
        if modifiers & (1 << 1) != 0 { parts.append("⇧") }
        if modifiers & (1 << 0) != 0 { parts.append("⌘") }
        
        parts.append(keyName(for: keyCode))
        
        return parts.joined(separator: " ")
    }
    
    private func keyName(for code: Int) -> String {
        let keyNames: [Int: String] = [
            49: "Space", 36: "↩", 48: "⇥", 51: "⌫", 53: "Esc",
            123: "←", 124: "→", 125: "↓", 126: "↑",
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
            23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
            30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P",
            37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\",
            43: ",", 44: "/", 45: "N", 46: "M", 47: ".",
            122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
            98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12",
        ]
        return keyNames[code] ?? "Key \(code)"
    }
}

#Preview {
    SettingsContentView(selectedSection: .general)
        .environmentObject(AppState())
}

extension Bundle {
    var appVersion: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
