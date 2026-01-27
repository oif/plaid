import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    
    // Use @ObservedObject for singletons that need bindings ($settings, $modelManager, etc.)
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var modelManager = ModelManager.shared
    @ObservedObject private var audioInputManager = AudioInputManager.shared
    
    // Local state for Keychain-backed API keys (required for SecureField binding)
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
        TabView {
            generalTab
                .tabItem {
                    Label("General", systemImage: "gear")
                }
            
            speechTab
                .tabItem {
                    Label("Speech", systemImage: "mic")
                }
            
            aiTab
                .tabItem {
                    Label("AI", systemImage: "sparkles")
                }
            
            modesTab
                .tabItem {
                    Label("Modes", systemImage: "square.stack.3d.up")
                }
            
            aboutTab
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 520, height: 480)
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
                    Text("fn + Space")
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                }
                
                Text("Press fn + Space to activate quick transcription mode")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
    
    private var speechTab: some View {
        Form {
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
            
            Section("Speech Recognition") {
                Picker("Provider", selection: $settings.sttProvider) {
                    ForEach(STTProvider.allCases, id: \.self) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
                
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
            }
            
            if settings.sttProvider == .sherpaLocal {
                Section("Local Model") {
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
                                .foregroundStyle(.red)
                            }
                        }
                    } else if modelManager.isModelDownloading(selectedModel) {
                        HStack {
                            ProgressView(value: modelManager.downloadProgress[selectedModel] ?? 0)
                            Text("\(Int((modelManager.downloadProgress[selectedModel] ?? 0) * 100))%")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                            Button("Cancel") {
                                modelManager.cancelDownload(selectedModel)
                            }
                        }
                    } else {
                        HStack {
                            Text("Model not downloaded")
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
                            .buttonStyle(.glass)
                        }
                    }
                    
                    if let error = showModelError {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            
            if settings.sttProvider == .elevenLabs {
                Section("ElevenLabs API") {
                    SecureField("API Key", text: $elevenLabsApiKey)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: elevenLabsApiKey) { _, newValue in
                            settings.elevenLabsApiKey = newValue
                        }
                    
                    Text("Get your API key at elevenlabs.io/app/settings/api-keys")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            if settings.sttProvider == .soniox {
                Section("Soniox API") {
                    SecureField("API Key", text: $sonioxApiKey)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: sonioxApiKey) { _, newValue in
                            settings.sonioxApiKey = newValue
                        }
                    
                    Text("Get your API key at console.soniox.com")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            if settings.sttProvider == .glmASR {
                Section("GLM ASR API (智谱)") {
                    SecureField("API Key", text: $glmApiKey)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: glmApiKey) { _, newValue in
                            settings.glmApiKey = newValue
                        }
                    
                    Text("Get your API key at open.bigmodel.cn")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            if settings.sttProvider == .customAPI {
                Section("Custom STT API") {
                    TextField("Endpoint URL", text: $settings.customSTTEndpoint)
                        .textFieldStyle(.roundedBorder)
                    
                    Text("e.g., https://api.example.com/v1/audio/transcriptions")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    SecureField("API Key", text: $customSTTApiKey)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: customSTTApiKey) { _, newValue in
                            settings.customSTTApiKey = newValue
                        }
                    
                    TextField("Model", text: $settings.customSTTModel)
                        .textFieldStyle(.roundedBorder)
                    
                    Text("Model name for the STT service (e.g., whisper-1)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
    
    private var aiTab: some View {
        Form {
            Section("Text Correction") {
                Toggle("Enable AI correction", isOn: $settings.enableLLMCorrection)
                
                if settings.enableLLMCorrection {
                    Picker("Provider", selection: $settings.llmProvider) {
                        ForEach(LLMProvider.allCases, id: \.self) { provider in
                            Text(provider.displayName).tag(provider)
                        }
                    }
                }
            }
            
            if settings.enableLLMCorrection && settings.llmProvider == .openAI {
                Section("OpenAI API") {
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
                    
                    Text("Also used for Whisper API if selected as STT provider")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            if settings.enableLLMCorrection && settings.llmProvider == .custom {
                Section("Custom LLM API (OpenAI Compatible)") {
                    TextField("Endpoint URL", text: $settings.customLLMEndpoint)
                        .textFieldStyle(.roundedBorder)
                    
                    Text("Base URL, e.g., https://api.example.com or https://api.example.com/v1")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    SecureField("API Key", text: $customLLMApiKey)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: customLLMApiKey) { _, newValue in
                            settings.customLLMApiKey = newValue
                        }
                    
                    TextField("Model", text: $settings.llmModel)
                        .textFieldStyle(.roundedBorder)
                    
                    Text("Model name for the LLM service")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            if needsStandaloneOpenAIKeySection {
                Section("OpenAI API (for Whisper)") {
                    SecureField("API Key", text: $apiKey)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: apiKey) { _, newValue in
                            settings.openAIKey = newValue
                        }
                    
                    Text("Required for OpenAI Whisper STT")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Section("Custom Vocabulary") {
                HStack {
                    TextField("Add word or phrase", text: $newVocabWord)
                    Button("Add") {
                        if !newVocabWord.isEmpty {
                            settings.customVocabulary.append(newVocabWord)
                            newVocabWord = ""
                        }
                    }
                    .buttonStyle(.glass)
                    .disabled(newVocabWord.isEmpty)
                }
                
                if !settings.customVocabulary.isEmpty {
                    ForEach(settings.customVocabulary, id: \.self) { word in
                        HStack {
                            Text(word)
                            Spacer()
                            Button {
                                settings.customVocabulary.removeAll { $0 == word }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
    
    private var modesTab: some View {
        Form {
            Section {
                ForEach(Mode.builtinModes) { mode in
                    ModeListRow(mode: mode, isBuiltin: true) { }
                }
            } header: {
                Text("Built-in Modes")
            } footer: {
                Text("Built-in modes cannot be modified")
            }
            
            Section {
                ForEach(settings.customModes) { mode in
                    ModeListRow(mode: mode, isBuiltin: false) {
                        editingMode = mode
                        showModeEditor = true
                    }
                    .contextMenu {
                        Button("Edit") {
                            editingMode = mode
                            showModeEditor = true
                        }
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
            } footer: {
                Text("Create custom modes with specific prompts for different use cases")
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
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Text(mode.icon)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(mode.name)
                        .font(.body)
                    
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
                    Section("System Prompt") {
                        TextEditor(text: $systemPrompt)
                            .frame(minHeight: 120)
                            .font(.body.monospaced())
                        
                        Text("The system prompt guides how the LLM processes your voice input")
                            .font(.caption)
                            .foregroundStyle(.secondary)
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

#Preview {
    SettingsView()
        .environmentObject(AppState())
}
