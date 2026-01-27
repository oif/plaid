import Foundation
import Combine

@MainActor
class TranscriptionPillState: ObservableObject {
    @Published var isVisible = false
    @Published var isRecording = false
    @Published var isProcessing = false
    @Published var errorMessage: String?
    @Published var waveformLevels: [Float] = Array(repeating: 0.1, count: 12)
    
    @Published var currentMode: Mode = Mode.defaultMode
    @Published var selectedText: String?
    @Published var showModeSelector = false
    @Published var fallbackNotice: String?
    
    private var sttService: STTService?
    private var llmService: LLMService?
    private var appContextService: AppContextService?
    private var cancellables = Set<AnyCancellable>()
    
    var onComplete: ((String) -> Void)?
    var onCancel: (() -> Void)?
    var onHide: (() -> Void)?
    
    func configure(sttService: STTService, llmService: LLMService, appContextService: AppContextService) {
        self.sttService = sttService
        self.llmService = llmService
        self.appContextService = appContextService
        
        sttService.$waveformSamples
            .throttle(for: 0.05, scheduler: RunLoop.main, latest: true)
            .sink { [weak self] samples in
                self?.updateWaveform(from: samples)
            }
            .store(in: &cancellables)
    }
    
    private func updateWaveform(from samples: [Float]) {
        guard isRecording else { return }
        let count = 12
        if samples.count >= count {
            waveformLevels = Array(samples.suffix(count))
        } else {
            waveformLevels = samples + Array(repeating: 0.1, count: count - samples.count)
        }
    }
    
    func show() {
        selectedText = appContextService?.getSelectedText()
        loadModeWithFallback()
        
        isVisible = true
        showModeSelector = false
        fallbackNotice = nil
        startRecording()
    }
    
    private func loadModeWithFallback() {
        let settings = AppSettings.shared
        let lastModeId = settings.lastSelectedModeId
        
        if let lastMode = settings.mode(byId: lastModeId) {
            if lastMode.useSelectedText && selectedText == nil {
                currentMode = Mode.defaultMode
                showFallbackNotice()
            } else {
                currentMode = lastMode
            }
        } else {
            currentMode = Mode.defaultMode
        }
    }
    
    private func showFallbackNotice() {
        fallbackNotice = "已切换到\(Mode.defaultMode.name)"
        Task {
            try? await Task.sleep(for: .seconds(2))
            fallbackNotice = nil
        }
    }
    
    func selectMode(_ mode: Mode) {
        currentMode = mode
        AppSettings.shared.lastSelectedModeId = mode.id
        showModeSelector = false
    }
    
    func toggleModeSelector() {
        showModeSelector.toggle()
    }
    
    func isModeAvailable(_ mode: Mode) -> Bool {
        if mode.useSelectedText && selectedText == nil {
            return false
        }
        return true
    }
    
    func hide() {
        isVisible = false
        isRecording = false
        isProcessing = false
        errorMessage = nil
        fallbackNotice = nil
        showModeSelector = false
        waveformLevels = Array(repeating: 0.1, count: 12)
        onHide?()
    }
    
    func toggle() {
        if isVisible {
            if isRecording {
                complete()
            } else if !isProcessing {
                cancel()
            }
        } else {
            show()
        }
    }
    
    func startRecording() {
        guard let sttService = sttService else {
            showError("Service not ready")
            return
        }
        
        isRecording = true
        errorMessage = nil
        
        Task {
            do {
                try await sttService.startListening { _ in }
            } catch {
                isRecording = false
                showError(friendlyError(error))
            }
        }
    }
    
    private func friendlyError(_ error: Error) -> String {
        let msg = error.localizedDescription.lowercased()
        if msg.contains("model") || msg.contains("config") {
            return "Model not ready"
        } else if msg.contains("microphone") || msg.contains("audio") {
            return "Mic unavailable"
        }
        return "Start failed"
    }
    
    private func showError(_ message: String) {
        errorMessage = message
        Task {
            try? await Task.sleep(for: .seconds(2))
            if errorMessage == message {
                hide()
            }
        }
    }
    
    func complete() {
        guard isRecording, let sttService = sttService else {
            hide()
            return
        }
        
        isRecording = false
        isProcessing = true
        
        Task {
            await Task.yield()
            
            do {
                let startTime = Date()
                var text = try await sttService.stopListening()
                let sttElapsed = Date().timeIntervalSince(startTime)
                
                if text.isEmpty {
                    hide()
                    return
                }
                
                let settings = AppSettings.shared
                let originalText = text
                var llmElapsed: Double? = nil
                
                if !currentMode.skipLLM,
                   let systemPrompt = currentMode.systemPrompt,
                   !settings.effectiveLLMApiKey.isEmpty,
                   let llmService = llmService {
                    let llmStart = Date()
                    let userMessage = buildUserMessage(voiceInput: text)
                    text = try await llmService.process(userMessage, systemPrompt: systemPrompt)
                    llmElapsed = Date().timeIntervalSince(llmStart)
                }
                
                TranscriptionHistoryService.shared.addRecord(
                    originalText: originalText,
                    correctedText: llmElapsed != nil ? text : nil,
                    sttProvider: settings.sttProvider.rawValue,
                    sttDuration: sttElapsed,
                    llmDuration: llmElapsed
                )
                
                hide()
                onComplete?(text)
            } catch {
                hide()
            }
        }
    }
    
    private func buildUserMessage(voiceInput: String) -> String {
        if currentMode.useSelectedText, let selected = selectedText {
            return """
            Selected text:
            \(selected)
            
            User instruction:
            \(voiceInput)
            """
        }
        return voiceInput
    }
    
    func cancel() {
        if isRecording {
            sttService?.cancel()
        }
        hide()
        onCancel?()
    }
}
