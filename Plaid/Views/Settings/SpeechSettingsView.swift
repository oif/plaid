import SwiftUI

struct SpeechSettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var modelManager: ModelManager
    
    // Bindings for API keys from parent
    @Binding var apiKey: String
    @Binding var customSTTApiKey: String
    @Binding var customLLMApiKey: String
    @Binding var elevenLabsApiKey: String
    @Binding var sonioxApiKey: String
    @Binding var glmApiKey: String
    
    // Local state
    @State private var newVocabWord = ""
    @State private var showModelError: String?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                processingModeSection
                sttSection
                audioProcessingSection
                llmSection
                vocabularySection
            }
            .padding()
        }
    }
    
    // MARK: - Processing Mode Section
    
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
    
    // MARK: - STT Section
    
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
    
    // MARK: - Audio Processing Section
    
    private var audioProcessingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AUDIO PROCESSING")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(0.5)
            
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Background Noise Reduction")
                            .font(.system(size: 14, weight: .medium))
                        Text("Filter out background noise before transcription. Disable when transcribing music or external audio.")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $settings.enableDenoising)
                        .labelsHidden()
                }
                .padding()
            }
            .background(.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
        }
    }
    
    // MARK: - LLM Section
    
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
                        
                        DisclosureGroup("Prompt") {
                            VStack(alignment: .leading, spacing: 12) {
                                promptEditor(
                                    title: "System Prompt",
                                    text: $settings.customSystemPrompt,
                                    defaultValue: AppSettings.defaultSystemPrompt,
                                    hint: "规则、示例等稳定指令（支持 prompt cache）"
                                )
                                
                                promptEditor(
                                    title: "User Prompt",
                                    text: $settings.customUserPrompt,
                                    defaultValue: AppSettings.defaultUserPrompt,
                                    hint: "{{context}} = 应用上下文, {{text}} = 转录文本"
                                )
                            }
                            .padding(.top, 8)
                        }
                        .font(.system(size: 12, weight: .medium))
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
    
    // MARK: - Vocabulary Section
    
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
                        .onSubmit { addVocabWord() }
                    Button("Add") { addVocabWord() }
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
    
    private func addVocabWord() {
        let trimmed = newVocabWord.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        settings.customVocabulary.append(trimmed)
        newVocabWord = ""
    }
    
    private func promptEditor(title: String, text: Binding<String>, defaultValue: String, hint: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                Spacer()
                if text.wrappedValue != defaultValue {
                    Button("Reset") {
                        text.wrappedValue = defaultValue
                    }
                    .font(.system(size: 11))
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
            }
            
            TextEditor(text: text)
                .font(.system(size: 12, design: .monospaced))
                .frame(minHeight: 60)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(.secondary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(.secondary.opacity(0.2), lineWidth: 1)
                )
            
            Text(hint)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Processing Mode Card

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

// MARK: - STT Provider Card

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

#Preview {
    SpeechSettingsView(
        apiKey: .constant(""),
        customSTTApiKey: .constant(""),
        customLLMApiKey: .constant(""),
        elevenLabsApiKey: .constant(""),
        sonioxApiKey: .constant(""),
        glmApiKey: .constant("")
    )
    .environmentObject(AppState())
    .environmentObject(AppSettings.shared)
    .environmentObject(ModelManager.shared)
    .frame(width: 500, height: 800)
}
