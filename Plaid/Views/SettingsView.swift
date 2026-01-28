import SwiftUI

struct SettingsContentView: View {
    let selectedSection: SettingsSection
    @EnvironmentObject var appState: AppState
    
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var modelManager = ModelManager.shared
    @ObservedObject private var audioInputManager = AudioInputManager.shared
    
    @State private var apiKey = ""
    @State private var customSTTApiKey = ""
    @State private var customLLMApiKey = ""
    @State private var elevenLabsApiKey = ""
    @State private var sonioxApiKey = ""
    @State private var glmApiKey = ""
    
    @State private var newVocabWord = ""
    @State private var showModelError: String?
    
    var body: some View {
        Group {
            switch selectedSection {
            case .general:
                generalTab
            case .speech:
                speechTab
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
        }
    }
    
    private var generalTab: some View {
        Form {
            Section {
                Toggle("Auto-inject text after recording", isOn: $settings.autoInject)
                
                Picker("Language", selection: $settings.language) {
                    Text("English (US)").tag("en-US")
                    Text("English (UK)").tag("en-GB")
                    Text("Chinese (Simplified)").tag("zh-CN")
                    Text("Chinese (Traditional)").tag("zh-TW")
                    Text("Japanese").tag("ja-JP")
                    Text("Korean").tag("ko-KR")
                    Text("Spanish").tag("es-ES")
                    Text("French").tag("fr-FR")
                    Text("German").tag("de-DE")
                }
                
                HStack {
                    Text("Accessibility Permission")
                    Spacer()
                    if appState.appContext.hasAccessibilityPermission {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Granted")
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Button("Grant Access") {
                            appState.appContext.requestAccessibilityPermission()
                        }
                        .buttonStyle(.glassCompat)
                    }
                }
            }
            
            Section("Hotkey") {
                HStack {
                    Text("Transcription Pill")
                    Spacer()
                    HotkeyRecorder(
                        keyCode: $settings.hotkeyKeyCode,
                        modifiers: $settings.hotkeyModifiers,
                        useFn: $settings.hotkeyUseFn
                    )
                }
            }
            
            Section("Updates") {
                Toggle("Automatically check for updates", isOn: Binding(
                    get: { SparkleUpdater.shared.automaticallyChecksForUpdates },
                    set: { SparkleUpdater.shared.automaticallyChecksForUpdates = $0 }
                ))
                
                HStack {
                    Button("Check for Updates…") {
                        SparkleUpdater.shared.checkForUpdates()
                    }
                    .disabled(!SparkleUpdater.shared.canCheckForUpdates)
                    
                    Spacer()
                    
                    if let lastCheck = SparkleUpdater.shared.lastUpdateCheckDate {
                        Text("Last checked: \(lastCheck, style: .relative) ago")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Section("Audio Input") {
                Picker("Input Device", selection: $audioInputManager.selectedDevice) {
                    ForEach(audioInputManager.availableDevices) { device in
                        HStack {
                            if device.isDefault && device.uid != "system_default" {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                    .font(.caption)
                            }
                            Text(device.name)
                        }
                        .tag(device)
                    }
                }
                
                Button {
                    audioInputManager.refreshDevices()
                } label: {
                    Label("Refresh Devices", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
    
    private var speechTab: some View {
        ScrollView {
            VStack(spacing: 24) {
                processingModeSection
                sttSection
                llmSection
                vocabularySection
            }
            .padding()
        }
    }
    
    private var processingModeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PROCESSING MODE")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(0.5)
            
            HStack(spacing: 12) {
                ProcessingModeCard(
                    icon: "laptopcomputer",
                    title: "Local",
                    description: "Process on device with your API keys",
                    isSelected: true
                )
                
                ProcessingModeCard(
                    icon: "cloud",
                    title: "Cloud",
                    description: "Coming Soon",
                    isSelected: false,
                    isDisabled: true
                )
            }
        }
    }
    
    private var sttSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SPEECH RECOGNITION")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(0.5)
            
            VStack(spacing: 8) {
                ForEach(STTProvider.allCases, id: \.self) { provider in
                    STTProviderCard(
                        provider: provider,
                        isSelected: settings.sttProvider == provider,
                        modelManager: modelManager,
                        settings: settings,
                        apiKey: apiKeyBinding(for: provider),
                        showModelError: $showModelError
                    ) {
                        settings.sttProvider = provider
                    }
                }
            }
        }
    }
    
    private func apiKeyBinding(for provider: STTProvider) -> Binding<String> {
        switch provider {
        case .whisperAPI:
            return $apiKey
        case .elevenLabs:
            return $elevenLabsApiKey
        case .soniox:
            return $sonioxApiKey
        case .glmASR:
            return $glmApiKey
        case .customAPI:
            return $customSTTApiKey
        default:
            return .constant("")
        }
    }
    
    private var llmSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TEXT ENHANCEMENT")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(0.5)
            
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("LLM Processing")
                            .font(.system(size: 14, weight: .medium))
                        Text("Use AI to correct and enhance transcriptions")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $settings.enableLLMCorrection)
                        .labelsHidden()
                }
                .padding()
                
                if settings.enableLLMCorrection {
                    Divider()
                        .padding(.horizontal)
                    
                    VStack(spacing: 12) {
                        Picker("Provider", selection: $settings.llmProvider) {
                            ForEach(LLMProvider.allCases, id: \.self) { provider in
                                Text(provider.displayName).tag(provider)
                            }
                        }
                        
                        if settings.llmProvider == .openAI {
                            SecureField("API Key", text: $apiKey)
                                .textFieldStyle(.roundedBorder)
                                .onChange(of: apiKey) { _, newValue in
                                    settings.openAIKey = newValue
                                }
                            
                            Picker("Model", selection: $settings.llmModel) {
                                Text("GPT-4o Mini").tag("gpt-4o-mini")
                                Text("GPT-4o").tag("gpt-4o")
                                Text("GPT-3.5 Turbo").tag("gpt-3.5-turbo")
                            }
                        }
                        
                        if settings.llmProvider == .custom {
                            TextField("Endpoint URL", text: $settings.customLLMEndpoint)
                                .textFieldStyle(.roundedBorder)
                            
                            SecureField("API Key", text: $customLLMApiKey)
                                .textFieldStyle(.roundedBorder)
                                .onChange(of: customLLMApiKey) { _, newValue in
                                    settings.customLLMApiKey = newValue
                                }
                            
                            TextField("Model", text: $settings.llmModel)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        Divider()
                            .padding(.vertical, 4)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Custom Prompt")
                                    .font(.system(size: 12, weight: .medium))
                                Spacer()
                                if settings.customPrompt != AppSettings.defaultPrompt {
                                    Button("Reset") {
                                        settings.customPrompt = AppSettings.defaultPrompt
                                    }
                                    .font(.system(size: 11))
                                    .buttonStyle(.plain)
                                    .foregroundStyle(.secondary)
                                }
                            }
                            
                            TextEditor(text: $settings.customPrompt)
                                .font(.system(size: 12, design: .monospaced))
                                .frame(minHeight: 80)
                                .scrollContentBackground(.hidden)
                                .padding(8)
                                .background(.secondary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .strokeBorder(.secondary.opacity(0.2), lineWidth: 1)
                                )
                            
                            Text("Use {{text}} for transcribed text")
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding()
                }
            }
            .background(.secondary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(.secondary.opacity(0.1), lineWidth: 1)
            )
        }
    }
    
    private var vocabularySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CUSTOM VOCABULARY")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(0.5)
            
            VStack(spacing: 0) {
                HStack {
                    TextField("Add word or phrase", text: $newVocabWord)
                        .textFieldStyle(.roundedBorder)
                    Button("Add") {
                        if !newVocabWord.isEmpty {
                            settings.customVocabulary.append(newVocabWord)
                            newVocabWord = ""
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(newVocabWord.isEmpty)
                }
                .padding()
                
                if !settings.customVocabulary.isEmpty {
                    Divider()
                        .padding(.horizontal)
                    
                    VStack(spacing: 0) {
                        ForEach(settings.customVocabulary, id: \.self) { word in
                            HStack {
                                Text(word)
                                    .font(.system(size: 13))
                                Spacer()
                                Button {
                                    settings.customVocabulary.removeAll { $0 == word }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                        }
                    }
                }
            }
            .background(.secondary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(.secondary.opacity(0.1), lineWidth: 1)
            )
        }
    }
    
    private var integrationsTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Connect Plaid to powerful third-party services")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                
                IntegrationCard(
                    icon: "sparkles",
                    iconColor: .purple,
                    title: "Claude Agent",
                    description: "Voice-controlled autonomous AI for research, analysis, and complex tasks",
                    status: .comingSoon
                )
                
                IntegrationCard(
                    icon: "macwindow.on.rectangle",
                    iconColor: .blue,
                    title: "Computer Use",
                    description: "Control your Mac with voice — open apps, click, navigate",
                    status: .comingSoon
                )
                
                IntegrationCard(
                    icon: "server.rack",
                    iconColor: .cyan,
                    title: "MCP Servers",
                    description: "Connect to Model Context Protocol servers for extended capabilities",
                    status: .comingSoon
                )
            }
            .padding(16)
        }
    }
    
    private var aboutTab: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 20)
                
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 96, height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                
                VStack(spacing: 6) {
                    Text("Plaid")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Version \(Bundle.main.appVersion)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Text("Speak naturally. Type instantly.")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                
                Text("Expanding human-computer interaction bandwidth.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                
                GlassContainer(spacing: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        aboutFeatureRow(icon: "mic.fill", color: .red, title: "Voice to Text", desc: "Local or cloud-powered speech recognition")
                        aboutFeatureRow(icon: "sparkles", color: .purple, title: "AI Enhancement", desc: "Smart correction with custom prompts")
                        aboutFeatureRow(icon: "globe", color: .blue, title: "Multi-language", desc: "Chinese, English, and more")
                        aboutFeatureRow(icon: "bolt.fill", color: .orange, title: "Instant Typing", desc: "Auto-inject text to any app")
                        aboutFeatureRow(icon: "lock.shield.fill", color: .green, title: "Privacy First", desc: "Local models, your data stays yours")
                    }
                    .padding(.vertical, 4)
                }
                
                GlassContainer(spacing: 12) {
                    VStack(spacing: 12) {
                        Text("Created by")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        
                        Text("Neo")
                            .font(.title3)
                            .fontWeight(.semibold)
                        
                        HStack(spacing: 16) {
                            Link(destination: URL(string: "https://oo.sb")!) {
                                Label("Website", systemImage: "globe")
                                    .font(.caption)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.tint)
                            
                            Link(destination: URL(string: "https://twitter.com/neoz_")!) {
                                Label("@neoz_", systemImage: "at")
                                    .font(.caption)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.tint)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                Text("Built with SwiftUI for macOS")
                    .font(.caption2)
                    .foregroundStyle(.quaternary)
                
                Spacer(minLength: 20)
            }
            .padding(.horizontal, 24)
        }
    }
    
    // MARK: - Diagnostics Tab
    
    private var diagnosticsTab: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 20)
                
                GlassContainer(spacing: 16) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("SYSTEM STATUS")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .tracking(0.5)
                        
                        DiagnosticStatusRow(
                            title: "Accessibility",
                            status: DiagnosticsManager.shared.isAccessibilityGranted ? "Granted" : "Denied",
                            isOK: DiagnosticsManager.shared.isAccessibilityGranted,
                            action: DiagnosticsManager.shared.isAccessibilityGranted ? nil : {
                                DiagnosticsManager.shared.requestAccessibilityPermission()
                            },
                            actionLabel: "Grant Access"
                        )
                        
                        DiagnosticStatusRow(
                            title: "Event Tap",
                            status: DiagnosticsManager.shared.eventTapStatus.rawValue,
                            isOK: DiagnosticsManager.shared.eventTapStatus == .active,
                            action: DiagnosticsManager.shared.eventTapStatus != .active ? {
                                GlobalHotkeyManager.shared.restart()
                            } : nil,
                            actionLabel: "Restart"
                        )
                        
                        if let error = DiagnosticsManager.shared.lastEventTapError {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                                Text(error)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                GlassContainer(spacing: 16) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("HOTKEY CONFIGURATION")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .tracking(0.5)
                        
                        HStack {
                            Text("Key Code")
                            Spacer()
                            Text("\(AppSettings.shared.hotkeyKeyCode)")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        
                        HStack {
                            Text("Use Fn Key")
                            Spacer()
                            Text(AppSettings.shared.hotkeyUseFn ? "Yes" : "No")
                                .foregroundStyle(.secondary)
                        }
                        
                        if let fnUsageType = UserDefaults.standard.persistentDomain(forName: "com.apple.HIToolbox")?["AppleFnUsageType"] as? Int, fnUsageType == 3, AppSettings.shared.hotkeyUseFn {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Fn Key Conflict Detected")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Text("System fn key is set to 'Start Dictation'. Change it in System Settings > Keyboard > Keyboard Shortcuts > Function Keys.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(12)
                            .background(Color.orange.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                GlassContainer(spacing: 16) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("LOGS & EXPORT")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .tracking(0.5)
                        
                        HStack(spacing: 12) {
                            Button {
                                copyDiagnosticsToClipboard()
                            } label: {
                                Label("Copy Diagnostics", systemImage: "doc.on.clipboard")
                            }
                            .buttonStyle(.glassCompat)
                            
                            Button {
                                exportLogsToFile()
                            } label: {
                                Label("Export Logs", systemImage: "square.and.arrow.up")
                            }
                            .buttonStyle(.glassCompat)
                            
                            Button {
                                DiagnosticsManager.shared.clearLogs()
                            } label: {
                                Label("Clear Logs", systemImage: "trash")
                            }
                            .buttonStyle(.glassCompat)
                        }
                        
                        Text("Logs are stored in Application Support/Plaid/plaid.log")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 4)
                }
                
                Spacer(minLength: 20)
            }
            .padding(.horizontal, 24)
        }
    }
    
    private func copyDiagnosticsToClipboard() {
        let diagnostics = DiagnosticsManager.shared.exportDiagnostics()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(diagnostics, forType: .string)
    }
    
    private func exportLogsToFile() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.text]
        panel.nameFieldStringValue = "plaid-diagnostics-\(Date().ISO8601Format()).txt"
        
        if panel.runModal() == .OK, let url = panel.url {
            let diagnostics = DiagnosticsManager.shared.exportDiagnostics()
            try? diagnostics.write(to: url, atomically: true, encoding: .utf8)
        }
    }
    
    private func aboutFeatureRow(icon: String, color: Color, title: String, desc: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)
                .frame(width: 28, height: 28)
                .background(color.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(desc)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
    }
    
    private var needsStandaloneOpenAIKeySection: Bool {
        let usingWhisper = settings.sttProvider == .whisperAPI
        let openAIKeyNotShownElsewhere = !settings.enableLLMCorrection || settings.llmProvider == .custom
        return usingWhisper && openAIKeyNotShownElsewhere
    }
}

enum IntegrationStatus {
    case available
    case comingSoon
    case beta
}

struct IntegrationCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    let status: IntegrationStatus
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(iconColor.opacity(0.8))
                .frame(width: 36, height: 36)
                .background(iconColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                    
                    statusBadge
                }
                
                Text(description)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            if status == .available {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(12)
        .background(isHovered ? Color.secondary.opacity(0.08) : Color.secondary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
    
    @ViewBuilder
    private var statusBadge: some View {
        switch status {
        case .available:
            EmptyView()
        case .comingSoon:
            Text("Coming soon")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.orange)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.orange.opacity(0.15), in: Capsule())
        case .beta:
            Text("Beta")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.blue)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.blue.opacity(0.15), in: Capsule())
        }
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

struct ProcessingModeCard: View {
    let icon: String
    let title: String
    let description: String
    let isSelected: Bool
    var isDisabled: Bool = false
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(isSelected ? .accent : .secondary)
            
            Text(title)
                .font(.system(size: 13, weight: .medium))
            
            Text(description)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(isSelected ? .accent.opacity(0.1) : .secondary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isSelected ? .accent.opacity(0.3) : .secondary.opacity(0.1), lineWidth: 1)
        )
        .opacity(isDisabled ? 0.5 : 1)
    }
}

struct STTProviderCard: View {
    let provider: STTProvider
    let isSelected: Bool
    @ObservedObject var modelManager: ModelManager
    @ObservedObject var settings: AppSettings
    @Binding var apiKey: String
    @Binding var showModelError: String?
    let onSelect: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Button(action: onSelect) {
                HStack {
                    Image(systemName: provider.icon)
                        .font(.system(size: 16))
                        .foregroundStyle(isSelected ? .accent : .secondary)
                        .frame(width: 32)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(provider.displayName)
                            .font(.system(size: 13, weight: .medium))
                        Text(provider.subtitle)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.accent)
                    }
                }
                .padding()
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            if isSelected {
                providerConfig
            }
        }
        .background(isSelected ? .accent.opacity(0.05) : .secondary.opacity(0.03), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isSelected ? .accent.opacity(0.2) : .secondary.opacity(0.08), lineWidth: 1)
        )
    }
    
    @ViewBuilder
    private var providerConfig: some View {
        Divider()
            .padding(.horizontal)
        
        VStack(spacing: 12) {
            switch provider {
            case .sherpaLocal:
                localModelConfig
                
            case .whisperAPI:
                SecureField("OpenAI API Key", text: $apiKey)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: apiKey) { _, newValue in
                        settings.openAIKey = newValue
                    }
                
            case .elevenLabs, .soniox, .glmASR:
                SecureField("API Key", text: $apiKey)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: apiKey) { _, newValue in
                        saveApiKey(newValue)
                    }
                
                if let hint = provider.apiHint {
                    Text(hint)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                
            case .customAPI:
                TextField("Endpoint URL", text: $settings.customSTTEndpoint)
                    .textFieldStyle(.roundedBorder)
                
                SecureField("API Key", text: $apiKey)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: apiKey) { _, newValue in
                        settings.customSTTApiKey = newValue
                    }
                
                TextField("Model", text: $settings.customSTTModel)
                    .textFieldStyle(.roundedBorder)
                
            case .appleSpeech:
                Text("Uses built-in macOS speech recognition")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }
    
    private var localModelConfig: some View {
        VStack(spacing: 12) {
            Picker("Model", selection: $modelManager.selectedModel) {
                ForEach(LocalModel.allCases) { model in
                    HStack {
                        Text(model.displayName)
                        if !modelManager.isModelAvailable(model) {
                            Text("(\(model.sizeDescription))")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tag(model)
                }
            }
            
            let selectedModel = modelManager.selectedModel
            
            if modelManager.isModelAvailable(selectedModel) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Ready to use")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Delete") {
                        do {
                            try modelManager.deleteModel(selectedModel)
                        } catch {
                            showModelError = error.localizedDescription
                        }
                    }
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
                }
            } else if modelManager.isModelDownloading(selectedModel) {
                HStack {
                    ProgressView(value: modelManager.downloadProgress[selectedModel] ?? 0)
                    Text("\(Int((modelManager.downloadProgress[selectedModel] ?? 0) * 100))%")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                    Button("Cancel") {
                        modelManager.cancelDownload(selectedModel)
                    }
                    .font(.system(size: 12))
                }
            } else {
                HStack {
                    Text("Model not downloaded")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Download (\(selectedModel.sizeDescription))") {
                        Task {
                            do {
                                try await modelManager.downloadModel(selectedModel)
                            } catch {
                                showModelError = error.localizedDescription
                            }
                        }
                    }
                    .font(.system(size: 12))
                    .buttonStyle(.borderedProminent)
                }
            }
            
            if let error = showModelError {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
            }
        }
    }
    
    private func saveApiKey(_ value: String) {
        switch provider {
        case .elevenLabs:
            settings.elevenLabsApiKey = value
        case .soniox:
            settings.sonioxApiKey = value
        case .glmASR:
            settings.glmApiKey = value
        default:
            break
        }
    }
}

struct DiagnosticStatusRow: View {
    let title: String
    let status: String
    let isOK: Bool
    var action: (() -> Void)?
    var actionLabel: String = "Fix"
    
    var body: some View {
        HStack {
            Image(systemName: isOK ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(isOK ? .green : .red)
            
            Text(title)
            
            Spacer()
            
            Text(status)
                .foregroundStyle(.secondary)
            
            if let action = action {
                Button(actionLabel, action: action)
                    .buttonStyle(.glassCompat)
                    .controlSize(.small)
            }
        }
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
