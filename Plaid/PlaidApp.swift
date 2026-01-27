import SwiftUI

@main
struct PlaidApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
        
        Window("Compact", id: "compact") {
            CompactWindowView()
                .environmentObject(appState)
        }
        .windowStyle(.plain)
        .windowResizability(.contentSize)
        .defaultPosition(.topTrailing)
        
        Settings {
            SettingsView()
                .environmentObject(appState)
        }
        
        MenuBarExtra {
            MenuBarView()
                .environmentObject(appState)
        } label: {
            Image(systemName: appState.isRecording ? "mic.fill" : "mic")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(appState.isRecording ? .red : .primary)
        }
        .menuBarExtraStyle(.window)
    }
}

struct TimingStats {
    var recordingDuration: TimeInterval = 0
    var sttDuration: TimeInterval = 0
    var llmDuration: TimeInterval = 0
    var injectDuration: TimeInterval = 0
    var totalDuration: TimeInterval = 0
    
    var formattedRecording: String { String(format: "%.1fs", recordingDuration) }
    var formattedSTT: String { String(format: "%.2fs", sttDuration) }
    var formattedLLM: String { String(format: "%.2fs", llmDuration) }
    var formattedInject: String { String(format: "%.0fms", injectDuration * 1000) }
    var formattedTotal: String { String(format: "%.2fs", totalDuration) }
}

@MainActor
class AppState: ObservableObject {
    @Published var isRecording = false
    @Published var transcribedText = ""
    @Published var correctedText = ""
    @Published var statusMessage = "Ready"
    @Published var isProcessing = false
    @Published var timing = TimingStats()
    @Published var recordingStartTime: Date?
    
    let sttService = STTService()
    let llmService = LLMService()
    let appContext = AppContextService()
    let textInjector = TextInjector()
    var settings = AppSettings.shared
    
    init() {
        Task {
            await initialize()
        }
    }
    
    func initialize() async {
        debugLog("initialize() start")
        statusMessage = "Initializing..."
        
        if !appContext.hasAccessibilityPermission {
            appContext.requestAccessibilityPermission()
        }
        
        do {
            debugLog("sttService.initialize() start")
            try await sttService.initialize()
            debugLog("sttService.initialize() done")
            
            if settings.sttProvider == .sherpaLocal {
                statusMessage = "Loading model..."
                await preloadLocalModel()
            }
            
            setupTranscriptionPill()
            
            statusMessage = "Ready"
        } catch {
            debugLog("ERROR: \(error.localizedDescription)")
            statusMessage = "Error: \(error.localizedDescription)"
        }
    }
    
    private func setupTranscriptionPill() {
        debugLog("setupTranscriptionPill called")
        let pillController = TranscriptionPillController.shared
        pillController.configure(sttService: sttService, llmService: llmService, textInjector: textInjector, appContextService: appContext)
        
        GlobalHotkeyManager.shared.onHotkeyPressed = {
            pillController.toggle()
        }
        GlobalHotkeyManager.shared.start()
        debugLog("GlobalHotkeyManager started")
    }
    
    private func debugLog(_ msg: String) {
        let str = "\(Date()): [App] \(msg)\n"
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
    
    private func preloadLocalModel() async {
        let model = await ModelManager.shared.selectedModel
        guard ModelManager.shared.isModelAvailable(model) else { return }
        
        do {
            try await SherpaOnnxService.shared.initializeAsync(with: model)
            SherpaOnnxService.shared.warmup()
            print("✅ Local model preloaded: \(model.displayName)")
        } catch {
            print("⚠️ Failed to preload model: \(error)")
        }
    }
    
    func startRecording() async {
        guard !isRecording else { return }
        
        isRecording = true
        transcribedText = ""
        correctedText = ""
        timing = TimingStats()
        statusMessage = "Listening..."
        recordingStartTime = Date()
        
        appContext.updateCurrentApp()
        
        do {
            try await sttService.startListening { [weak self] partial in
                Task { @MainActor in
                    self?.transcribedText = partial
                }
            }
        } catch {
            statusMessage = "Error: \(error.localizedDescription)"
            isRecording = false
        }
    }
    
    func stopRecording() async {
        guard isRecording else { return }
        
        let totalStart = Date()
        
        if let recordStart = recordingStartTime {
            timing.recordingDuration = Date().timeIntervalSince(recordStart)
        }
        
        isRecording = false
        statusMessage = "Transcribing..."
        isProcessing = true
        
        do {
            let sttStart = Date()
            let result = try await sttService.stopListening()
            timing.sttDuration = Date().timeIntervalSince(sttStart)
            
            transcribedText = result
            
            if settings.enableLLMCorrection && !settings.effectiveLLMApiKey.isEmpty {
                statusMessage = "Correcting with AI..."
                let llmStart = Date()
                let context = appContext.getCurrentContext()
                correctedText = try await llmService.correctText(result, context: context) { [weak self] partial in
                    Task { @MainActor in
                        self?.correctedText = partial
                    }
                }
                timing.llmDuration = Date().timeIntervalSince(llmStart)
            } else {
                correctedText = result
                timing.llmDuration = 0
            }
            
            if settings.autoInject && !correctedText.isEmpty {
                statusMessage = "Typing..."
                let injectStart = Date()
                textInjector.inject(correctedText)
                timing.injectDuration = Date().timeIntervalSince(injectStart)
            }
            
            timing.totalDuration = Date().timeIntervalSince(totalStart)
            statusMessage = "Done"
            
            print("📊 Timing: Recording=\(timing.formattedRecording), STT=\(timing.formattedSTT), LLM=\(timing.formattedLLM), Inject=\(timing.formattedInject), Total=\(timing.formattedTotal)")
            
        } catch {
            statusMessage = "Error: \(error.localizedDescription)"
        }
        
        isProcessing = false
    }
    
    func toggleRecording() async {
        if isRecording {
            await stopRecording()
        } else {
            await startRecording()
        }
    }
    
    func processAudioFile(at url: URL) async {
        guard !isRecording && !isProcessing else { return }
        
        let totalStart = Date()
        timing = TimingStats()
        
        statusMessage = "Transcribing file..."
        isProcessing = true
        transcribedText = ""
        correctedText = ""
        
        do {
            let sttStart = Date()
            let result = try await sttService.transcribeFile(at: url)
            timing.sttDuration = Date().timeIntervalSince(sttStart)
            
            transcribedText = result
            
            if settings.enableLLMCorrection && !settings.effectiveLLMApiKey.isEmpty {
                statusMessage = "Correcting with AI..."
                let llmStart = Date()
                let context = appContext.getCurrentContext()
                correctedText = try await llmService.correctText(result, context: context) { [weak self] partial in
                    Task { @MainActor in
                        self?.correctedText = partial
                    }
                }
                timing.llmDuration = Date().timeIntervalSince(llmStart)
            } else {
                correctedText = result
                timing.llmDuration = 0
            }
            
            timing.totalDuration = Date().timeIntervalSince(totalStart)
            statusMessage = "Done"
            
            print("📊 File Timing: STT=\(timing.formattedSTT), LLM=\(timing.formattedLLM), Total=\(timing.formattedTotal)")
            
        } catch {
            statusMessage = "Error: \(error.localizedDescription)"
        }
        
        isProcessing = false
    }
}

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.openWindow) private var openWindow
    @Namespace private var menuNamespace
    
    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Text("Plaid")
                    .font(.headline)
                Spacer()
                if appState.isRecording {
                    CompactWaveformView(level: appState.sttService.audioLevel)
                        .tint(.red)
                } else {
                    Circle()
                        .fill(.green)
                        .frame(width: 10, height: 10)
                }
            }
            
            Divider()
            
            GlassEffectContainer(spacing: 12) {
                Button {
                    Task {
                        await appState.toggleRecording()
                    }
                } label: {
                    HStack {
                        Image(systemName: appState.isRecording ? "stop.fill" : "mic.fill")
                        Text(appState.isRecording ? "Stop Recording" : "Start Recording")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .tint(appState.isRecording ? .red : .accentColor)
                .keyboardShortcut("r", modifiers: [.command])
                .glassEffectID("recordButton", in: menuNamespace)
            }
            
            Text(appState.statusMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
            
            Divider()
            
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 10) {
                    Button {
                        openWindow(id: "compact")
                    } label: {
                        Image(systemName: "pip")
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                    .glassEffectID("compact", in: menuNamespace)
                    .help("Compact Mode")
                    
                    Button {
                        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                    } label: {
                        Image(systemName: "gear")
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                    .keyboardShortcut(",", modifiers: [.command])
                    .glassEffectID("settings", in: menuNamespace)
                    
                    Button {
                        NSApp.terminate(nil)
                    } label: {
                        Image(systemName: "power")
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                    .tint(.red)
                    .keyboardShortcut("q", modifiers: [.command])
                    .glassEffectID("quit", in: menuNamespace)
                }
            }
        }
        .padding(16)
        .frame(width: 220)
    }
}
