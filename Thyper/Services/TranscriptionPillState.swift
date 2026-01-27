import Foundation
import Combine

@MainActor
class TranscriptionPillState: ObservableObject {
    @Published var isVisible = false
    @Published var isRecording = false
    @Published var isProcessing = false
    @Published var waveformLevels: [Float] = Array(repeating: 0.1, count: 7)
    
    private var sttService: STTService?
    private var llmService: LLMService?
    private var cancellables = Set<AnyCancellable>()
    
    var onComplete: ((String) -> Void)?
    var onCancel: (() -> Void)?
    var onHide: (() -> Void)?
    
    func configure(sttService: STTService, llmService: LLMService) {
        self.sttService = sttService
        self.llmService = llmService
        
        sttService.$waveformSamples
            .receive(on: DispatchQueue.main)
            .sink { [weak self] samples in
                self?.updateWaveform(from: samples)
            }
            .store(in: &cancellables)
    }
    
    private func updateWaveform(from samples: [Float]) {
        guard isRecording else { return }
        let count = 7
        if samples.count >= count {
            waveformLevels = Array(samples.suffix(count))
        } else {
            waveformLevels = samples + Array(repeating: 0.1, count: count - samples.count)
        }
    }
    
    func show() {
        isVisible = true
        startRecording()
    }
    
    func hide() {
        isVisible = false
        isRecording = false
        isProcessing = false
        waveformLevels = Array(repeating: 0.1, count: 7)
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
        guard let sttService = sttService else { return }
        
        isRecording = true
        
        Task {
            do {
                try await sttService.startListening { _ in }
            } catch {
                print("Recording error: \(error)")
                hide()
            }
        }
    }
    
    private func log(_ msg: String) {
        let str = "\(Date()): [PillState] \(msg)\n"
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
    
    func complete() {
        log("complete() called, isRecording=\(isRecording), sttService=\(sttService != nil)")
        guard isRecording, let sttService = sttService else {
            log("complete() guard failed, hiding")
            hide()
            return
        }
        
        isRecording = false
        isProcessing = true
        log("complete() set isProcessing=true")
        
        Task {
            await Task.yield()
            
            do {
                let startTime = Date()
                log("complete() awaiting STT...")
                var text = try await sttService.stopListening()
                let sttElapsed = Date().timeIntervalSince(startTime)
                log("complete() STT returned in \(String(format: "%.2f", sttElapsed))s: '\(text)' (length=\(text.count))")
                
                if text.isEmpty {
                    log("complete() text is empty, not injecting")
                    hide()
                    return
                }
                
                let settings = AppSettings.shared
                let originalText = text
                var llmElapsed: Double? = nil
                
                if settings.enableLLMCorrection && !settings.effectiveLLMApiKey.isEmpty,
                   let llmService = llmService {
                    log("complete() awaiting LLM correction...")
                    let llmStart = Date()
                    let context = AppContext(appName: nil, bundleId: nil, focusedElement: nil)
                    text = try await llmService.correctText(text, context: context)
                    llmElapsed = Date().timeIntervalSince(llmStart)
                    log("complete() LLM returned in \(String(format: "%.2f", llmElapsed!))s: '\(text)'")
                }
                
                TranscriptionHistoryService.shared.addRecord(
                    originalText: originalText,
                    correctedText: llmElapsed != nil ? text : nil,
                    sttProvider: settings.sttProvider.rawValue,
                    sttDuration: sttElapsed,
                    llmDuration: llmElapsed
                )
                
                hide()
                log("complete() calling onComplete")
                onComplete?(text)
            } catch {
                log("complete() error: \(error)")
                hide()
            }
        }
    }
    
    func cancel() {
        if isRecording {
            sttService?.cancel()
        }
        hide()
        onCancel?()
    }
}
