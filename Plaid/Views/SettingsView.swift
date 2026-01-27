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
    @State private var editingMode: Mode?
    @State private var showModeEditor = false
    
    var body: some View {
        Group {
            switch selectedSection {
            case .general:
                generalTab
            case .services:
                servicesTab
            case .modes:
                modesTab
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
                        .buttonStyle(.glass)
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
    
    private var servicesTab: some View {
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
    
    private var modesTab: some View {
        Form {
            Section("Default Mode") {
                Picker("Default", selection: $settings.defaultModeId) {
                    ForEach(settings.allModes) { mode in
                        HStack {
                            Text(mode.icon)
                            Text(mode.name)
                        }
                        .tag(mode.id)
                    }
                }
            }
            
            Section {
                ForEach(Mode.builtinModes) { mode in
                    ModeListRow(mode: mode, isBuiltin: true, isDefault: mode.id == settings.defaultModeId) { }
                }
            } header: {
                Text("Built-in Modes")
            }
            
            Section {
                ForEach(settings.customModes) { mode in
                    ModeListRow(mode: mode, isBuiltin: false, isDefault: mode.id == settings.defaultModeId) {
                        editingMode = mode
                        showModeEditor = true
                    }
                    .contextMenu {
                        Button("Edit") {
                            editingMode = mode
                            showModeEditor = true
                        }
                        Button("Set as Default") {
                            settings.defaultModeId = mode.id
                        }
                        Divider()
                        Button("Delete", role: .destructive) {
                            settings.customModes.removeAll { $0.id == mode.id }
                        }
                    }
                }
                .onDelete { indexSet in
                    settings.customModes.remove(atOffsets: indexSet)
                }
                
                Button {
                    editingMode = nil
                    showModeEditor = true
                } label: {
                    Label("Add Mode", systemImage: "plus")
                }
            } header: {
                Text("Custom Modes")
            }
        }
        .formStyle(.grouped)
        .padding()
        .sheet(isPresented: $showModeEditor) {
            ModeEditorView(mode: editingMode) { savedMode in
                if let existing = editingMode {
                    if let index = settings.customModes.firstIndex(where: { $0.id == existing.id }) {
                        settings.customModes[index] = savedMode
                    }
                } else {
                    settings.customModes.append(savedMode)
                }
            }
        }
    }
    
    private var aboutTab: some View {
        VStack(spacing: 28) {
            Spacer()
            
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(.tint)
            
            VStack(spacing: 6) {
                Text("Plaid")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Version 1.0")
                    .foregroundStyle(.secondary)
            }
            
            Text("AI-powered voice dictation for macOS")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            GlassEffectContainer(spacing: 20) {
                HStack(spacing: 28) {
                    featureItem(icon: "mic.fill", text: "Voice Input")
                    featureItem(icon: "sparkles", text: "AI Correction")
                    featureItem(icon: "keyboard", text: "Auto Type")
                }
            }
            
            Spacer()
        }
        .padding()
    }
    
    private var needsStandaloneOpenAIKeySection: Bool {
        let usingWhisper = settings.sttProvider == .whisperAPI
        let openAIKeyNotShownElsewhere = !settings.enableLLMCorrection || settings.llmProvider == .custom
        return usingWhisper && openAIKeyNotShownElsewhere
    }
    
    private func featureItem(icon: String, text: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title2)
                .frame(width: 48, height: 48)
                .glassEffect(.regular.tint(.accentColor.opacity(0.2)).interactive(), in: .circle)
            
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct ModeListRow: View {
    let mode: Mode
    let isBuiltin: Bool
    var isDefault: Bool = false
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Text(mode.icon)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(mode.name)
                            .font(.body)
                        if isDefault {
                            Text("Default")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.accent.opacity(0.15), in: Capsule())
                                .foregroundStyle(.accent)
                        }
                    }
                    
                    HStack(spacing: 8) {
                        if mode.skipLLM {
                            Label("No LLM", systemImage: "bolt.slash")
                        }
                        if mode.useSelectedText {
                            Label("Uses Selection", systemImage: "text.cursor")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                if isBuiltin {
                    Text("Built-in")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isBuiltin)
    }
}

struct ModeEditorView: View {
    let mode: Mode?
    let onSave: (Mode) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String = ""
    @State private var icon: String = "🔮"
    @State private var systemPrompt: String = ""
    @State private var skipLLM: Bool = false
    @State private var useSelectedText: Bool = false
    
    private let emojiOptions = ["🔮", "💬", "✍️", "🎯", "🔥", "💡", "🎨", "🤖", "📝", "🌟", "⚡️", "🎭"]
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                Spacer()
                Text(mode == nil ? "New Mode" : "Edit Mode")
                    .font(.headline)
                Spacer()
                Button("Save") { saveMode() }
                    .buttonStyle(.borderedProminent)
                    .disabled(name.isEmpty || (!skipLLM && systemPrompt.isEmpty))
            }
            .padding()
            
            Divider()
            
            Form {
                Section("Basic Info") {
                    TextField("Name", text: $name)
                    
                    HStack {
                        Text("Icon")
                        Spacer()
                        HStack(spacing: 8) {
                            ForEach(emojiOptions, id: \.self) { emoji in
                                Button {
                                    icon = emoji
                                } label: {
                                    Text(emoji)
                                        .font(.title2)
                                        .padding(4)
                                        .background(icon == emoji ? Color.accentColor.opacity(0.3) : Color.clear)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                
                Section("Behavior") {
                    Toggle("Skip LLM processing", isOn: $skipLLM)
                    Toggle("Use selected text as context", isOn: $useSelectedText)
                }
                
                if !skipLLM {
                    Section {
                        TextEditor(text: $systemPrompt)
                            .frame(minHeight: 120)
                            .font(.body.monospaced())
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Available variables:")
                                .font(.caption)
                                .fontWeight(.medium)
                            
                            HStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("{{voice_input}}")
                                        .font(.caption.monospaced())
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 4))
                                    Text("Voice transcription")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                
                                if useSelectedText {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("{{selected_text}}")
                                            .font(.caption.monospaced())
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 4))
                                        Text("Text selected before activation")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        .padding(.top, 4)
                    } header: {
                        Text("System Prompt")
                    }
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 500, height: 480)
        .onAppear {
            if let mode = mode {
                name = mode.name
                icon = mode.icon
                systemPrompt = mode.systemPrompt ?? ""
                skipLLM = mode.skipLLM
                useSelectedText = mode.useSelectedText
            }
        }
    }
    
    private func saveMode() {
        let newMode = Mode(
            id: mode?.id ?? UUID().uuidString,
            name: name,
            icon: icon,
            systemPrompt: skipLLM ? nil : systemPrompt,
            skipLLM: skipLLM,
            useSelectedText: useSelectedText,
            isBuiltin: false
        )
        onSave(newMode)
        dismiss()
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
                    if !selectedModel.isBundled {
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

#Preview {
    SettingsContentView(selectedSection: .general)
        .environmentObject(AppState())
}
